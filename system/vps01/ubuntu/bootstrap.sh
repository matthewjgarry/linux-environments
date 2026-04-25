#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
MACHINE_ID_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/machine-id"

EXPECTED_MACHINE="${1:-vps01}"
EXPECTED_OS="ubuntu"
MACHINE_LABEL="Wormlogic VPS"

verify_machine_id() {
  if [[ ! -f "$MACHINE_ID_FILE" ]]; then
    echo "✗ Missing machine-id file: $MACHINE_ID_FILE"
    exit 1
  fi

  local actual_machine
  actual_machine="$(<"$MACHINE_ID_FILE")"

  if [[ "$actual_machine" != "$EXPECTED_MACHINE" ]]; then
    echo "✗ Machine identity mismatch"
    echo "  Expected: $EXPECTED_MACHINE"
    echo "  Found:    $actual_machine"
    exit 1
  fi

  echo "✓ Machine identity verified: $actual_machine"
}

verify_os() {
  if ! command -v apt >/dev/null 2>&1; then
    echo "✗ Ubuntu bootstrap called on non-Ubuntu system"
    exit 1
  fi

  echo "✓ Operating system verified: $EXPECTED_OS"
}

prepare_ubuntu_repos() {
  echo "📦 Preparing Ubuntu repositories..."

  sudo apt-get update
  sudo apt-get install -y software-properties-common curl ca-certificates gnupg

  sudo add-apt-repository -y universe
  sudo add-apt-repository -y multiverse

  sudo apt-get update
  sudo apt-get upgrade -y

  echo "✓ Ubuntu repositories ready"
}

ensure_nala() {
  if command -v nala >/dev/null 2>&1; then
    echo "✓ nala is available"
    return 0
  fi

  echo "📦 Installing nala..."
  sudo apt-get install -y nala
}

install_docker_repo() {
  echo "🐳 Configuring Docker apt repository..."

  sudo apt-get update
  sudo apt-get install -y ca-certificates curl gnupg

  sudo install -m 0755 -d /etc/apt/keyrings

  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

  sudo chmod a+r /etc/apt/keyrings/docker.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

  sudo apt-get update

  echo "✓ Docker apt repository configured"
}

initial_update() {
  echo "📦 Running system update..."
  sudo nala update
  sudo nala upgrade -y
}

install_packages() {
  local package_dir="$REPO_ROOT/system/$EXPECTED_MACHINE/$EXPECTED_OS"
  local apt_file="$package_dir/apt.txt"

  if [[ ! -f "$apt_file" ]]; then
    echo "⚠ No apt.txt found at $apt_file, skipping"
    return 0
  fi

  echo "📦 Installing packages from $apt_file..."

  mapfile -t apt_packages < <(grep -vE '^\s*(#|$)' "$apt_file")

  if ((${#apt_packages[@]} > 0)); then
    sudo nala install -y "${apt_packages[@]}"
  else
    echo "⚠ apt.txt exists but is empty, skipping"
  fi
}

install_docker_engine() {
  echo "🐳 Installing Docker Engine..."

  sudo apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

  sudo systemctl enable --now docker
  sudo usermod -aG docker "$USER" || true

  echo "✓ Docker Engine installed"
}

setup_age_and_sops() {
  local age_base_dir="${XDG_CONFIG_HOME:-$HOME/.config}/sops"
  local age_dir="$age_base_dir/age"
  local key_file="$age_dir/keys.txt"
  local dotfiles_dir="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"
  local public_key_file="$dotfiles_dir/age-public-key"
  local public_key=""
  local sops_version=""

  echo "🔐 Setting up age + sops..."

  if ! command -v age-keygen >/dev/null 2>&1; then
    echo "✗ age-keygen not found. Make sure 'age' is in apt.txt"
    exit 1
  fi

  if ! command -v sops >/dev/null 2>&1; then
    echo "🔐 Installing sops..."
    sops_version="$(curl -s https://api.github.com/repos/getsops/sops/releases/latest | grep tag_name | cut -d'"' -f4)"

    if [[ -z "$sops_version" ]]; then
      echo "✗ Failed to determine latest sops version"
      exit 1
    fi

    curl -Lo /tmp/sops.deb "https://github.com/getsops/sops/releases/download/${sops_version}/sops_${sops_version#v}_amd64.deb"
    sudo dpkg -i /tmp/sops.deb
    rm -f /tmp/sops.deb
  else
    echo "✓ sops already installed"
  fi

  mkdir -p "$age_dir"
  chmod 700 "$age_base_dir" "$age_dir"

  if [[ ! -f "$key_file" ]]; then
    age-keygen -o "$key_file"
    echo "✓ age key generated"
  else
    echo "✓ Existing age key found"
  fi

  chmod 600 "$key_file"

  public_key="$(grep 'public key:' "$key_file" | awk '{print $4}')"

  if [[ -z "$public_key" ]]; then
    echo "✗ Failed to extract public key from $key_file"
    exit 1
  fi

  mkdir -p "$dotfiles_dir"
  printf '%s\n' "$public_key" > "$public_key_file"
  chmod 600 "$public_key_file"

  echo "✓ age + sops ready"
  echo "  Public key:  $public_key"
  echo "  Private key: $key_file"
}

ensure_ssh_key() {
  local ssh_dir="$HOME/.ssh"
  local key_file="$ssh_dir/id_ed25519"
  local pub_file="${key_file}.pub"

  echo "🔑 Checking for SSH key..."

  mkdir -p "$ssh_dir"
  chmod 700 "$ssh_dir"

  if [[ -f "$pub_file" ]]; then
    echo "✓ SSH public key already exists"
    return 0
  fi

  if [[ -f "$key_file" ]]; then
    ssh-keygen -y -f "$key_file" > "$pub_file"
    chmod 644 "$pub_file"
    echo "✓ SSH public key regenerated from private key"
    return 0
  fi

  ssh-keygen -t ed25519 -f "$key_file" -N "" -C "vps01-$(hostname)"
  chmod 600 "$key_file"
  chmod 644 "$pub_file"

  echo "✓ SSH key generated"
}

install_starship() {
  if command -v starship >/dev/null 2>&1; then
    echo "✓ starship already installed"
    return 0
  fi

  echo "⭐ Installing starship..."
  curl -sS https://starship.rs/install.sh | sh -s -- -y
}

set_user_environment_defaults() {
  echo "⚙ Setting user environment defaults..."

  mkdir -p "$HOME/.config/environment.d"
  mkdir -p "$HOME/.local/bin"

  cat >"$HOME/.config/environment.d/path.conf" <<'ENVEOF'
PATH=$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin
ENVEOF

  cat >"$HOME/.config/environment.d/defaults.conf" <<'ENVEOF'
EDITOR=nvim
VISUAL=nvim
BROWSER=firefox
ENVEOF

  if command -v git >/dev/null 2>&1 && command -v nvim >/dev/null 2>&1; then
    git config --global core.editor "nvim"
    git config --global sequence.editor "nvim"
  fi

  echo "✓ Environment defaults configured"
}

user_systemd_available() {
  systemctl --user status >/dev/null 2>&1
}

setup_user_service_pair() {
  local name="$1"

  if ! user_systemd_available; then
    echo "⚠ User systemd unavailable; skipping $name"
    return 0
  fi

  mkdir -p "$HOME/.config/systemd/user"

  cp "$REPO_ROOT/systemd/${name}.service" "$HOME/.config/systemd/user/"
  cp "$REPO_ROOT/systemd/${name}.timer" "$HOME/.config/systemd/user/"

  systemctl --user daemon-reload
  systemctl --user enable --now "${name}.timer"
}

setup_package_export() {
  echo "⚙ Setting up package export service and timer..."
  setup_user_service_pair "package-export"
}

setup_system_update() {
  echo "⚙ Setting up system update service and timer..."
  setup_user_service_pair "system-update"
}

setup_git_monitoring() {
  echo "⚙ Setting up git monitoring services and timers..."
  setup_user_service_pair "repo-update-check"
  setup_user_service_pair "dotfiles-change-check"
}

setup_shared_monitoring() {
  echo "⚙ Setting up shared monitoring services and timers..."
  setup_user_service_pair "disk-space-check"
  setup_user_service_pair "heartbeat"
}

setup_remote_unlock() {
  echo "• Remote unlock skipped on VPS"
}

prepare_shell_dotfiles() {
  local backup_dir="$HOME/.dotfile-backups/$(date +%Y%m%d-%H%M%S)"
  local files=("$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.bash_logout")

  echo "🐚 Preparing shell dotfiles for stow..."

  for file in "${files[@]}"; do
    if [[ -L "$file" ]]; then
      echo "✓ $file is already a symlink"
    elif [[ -f "$file" ]]; then
      mkdir -p "$backup_dir"
      mv "$file" "$backup_dir/"
      echo "✓ Backed up $(basename "$file")"
    fi
  done
}

apply_bash_stow() {
  echo "🐚 Stowing bash config..."
  stow -d "$REPO_ROOT/stow" -t "$HOME" bash
}

apply_host_environment() {
  local host_dir="$REPO_ROOT/hosts/$EXPECTED_MACHINE/$EXPECTED_OS"

  if [[ ! -d "$host_dir" ]]; then
    echo "⚠ No host-specific environment found at $host_dir, skipping"
    return 0
  fi

  echo "⚙ Applying host-specific environment from $host_dir..."

  for dir in "$host_dir"/*; do
    if [[ -d "$dir" ]]; then
      local name
      name="$(basename "$dir")"
      stow -d "$host_dir" -t "$HOME" "$name"
    fi
  done
}

run_package_export() {
  if [[ -x "$REPO_ROOT/scripts/package-export.sh" ]]; then
    echo "📦 Exporting current package state..."
    "$REPO_ROOT/scripts/package-export.sh"
  else
    echo "⚠ package-export.sh not found or not executable, skipping"
  fi
}

show_summary() {
  local git_name git_email local_ip
  git_name="$(git config --global user.name || echo "unset")"
  git_email="$(git config --global user.email || echo "unset")"
  local_ip="$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") {print $(i+1); exit}}' || true)"
  local_ip="${local_ip:-unavailable}"

  echo
  echo "=================================================="
  echo "✓ Bootstrap complete for $MACHINE_LABEL ($EXPECTED_MACHINE)"
  echo "=================================================="
  echo
  echo "Git user:"
  echo "  Name:  $git_name"
  echo "  Email: $git_email"
  echo
  echo "Local IP:"
  echo "  $local_ip"
  echo
  echo "Services configured:"
  echo "  - package-export       → state tracking"
  echo "  - system-update        → scheduled system maintenance"
  echo "  - repo-update-check    → remote update awareness"
  echo "  - dotfiles-change-check → local dotfiles drift awareness"
  echo "  - disk-space-check     → local disk usage warning"
  echo "  - heartbeat            → device online signal"
  echo "  - remote-unlock        → skipped on VPS"
  echo
  echo "Docker:"
  docker --version || true
  docker compose version || true
}

prompt_reboot() {
  echo
  read -r -p "Press Enter to reboot, or Ctrl+C to skip..."
  sudo reboot
}

main() {
  echo "🚀 Starting bootstrap for $MACHINE_LABEL ($EXPECTED_MACHINE)..."
  echo

  verify_machine_id
  verify_os
  prepare_ubuntu_repos
  ensure_nala
  install_docker_repo
  initial_update
  install_packages
  install_docker_engine
  setup_age_and_sops
  ensure_ssh_key
  install_starship
  set_user_environment_defaults
  setup_remote_unlock
  setup_package_export
  setup_system_update
  setup_git_monitoring
  setup_shared_monitoring
  prepare_shell_dotfiles
  apply_bash_stow
  apply_host_environment
  run_package_export
  show_summary
  prompt_reboot
}

main "$@"
