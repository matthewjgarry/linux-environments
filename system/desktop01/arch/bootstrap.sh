#!/usr/bin/env bash

set -euo pipefail

# --------------------------------------------------
# Resolve repo root and machine identity file path
# --------------------------------------------------
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
MACHINE_ID_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/machine-id"
EXPECTED_MACHINE="${1:-desktop01}"
EXPECTED_OS="arch"
MACHINE_LABEL="Covid PC"

# --------------------------------------------------
# Verify machine identity
# --------------------------------------------------
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

# --------------------------------------------------
# Verify operating system
# --------------------------------------------------
verify_os() {
  if ! command -v pacman >/dev/null 2>&1; then
    echo "✗ Arch bootstrap called on non-Arch system"
    exit 1
  fi

  echo "✓ Operating system verified: $EXPECTED_OS"
}

# --------------------------------------------------
# Enable multilib repository in pacman.conf
# --------------------------------------------------
enable_multilib() {
  echo "📦 Enabling multilib repository..."
  sudo sed -i '/\[multilib\]/,/Include/ s/^#//' /etc/pacman.conf
}

# --------------------------------------------------
# Perform initial system update
# --------------------------------------------------
initial_update() {
  echo "🔄 Performing initial system update..."
  sudo pacman -Syu --noconfirm
}

# --------------------------------------------------
# Ensure yay is available
# --------------------------------------------------
ensure_yay() {
  if command -v yay >/dev/null 2>&1; then
    echo "✓ yay is available"
    return 0
  fi

  echo "📦 yay not found. Installing yay..."
  sudo pacman -S --needed --noconfirm base-devel git

  local tmpdir
  tmpdir="$(mktemp -d)"
  git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
  pushd "$tmpdir/yay" >/dev/null
  makepkg -si --noconfirm
  popd >/dev/null
  rm -rf "$tmpdir"

  echo "✓ yay installed"
}

# --------------------------------------------------
# Install Flatpak and configure Flathub if needed
# --------------------------------------------------
ensure_flatpak() {
  if ! command -v flatpak >/dev/null 2>&1; then
    echo "📦 flatpak not found. Installing flatpak..."
    yay -S --needed --noconfirm flatpak
  else
    echo "✓ flatpak is available"
  fi

  if ! flatpak remotes --columns=name 2>/dev/null | grep -qx "flathub"; then
    echo "🌐 Adding Flathub remote..."
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  else
    echo "✓ Flathub remote already configured"
  fi

  echo "🔄 Updating Flatpak metadata..."
  flatpak update -y || true
}

# --------------------------------------------------
# Install packages from machine-specific lists
# --------------------------------------------------
install_packages() {
  local package_dir="$REPO_ROOT/system/$EXPECTED_MACHINE/$EXPECTED_OS"
  local pacman_file="$package_dir/pacman.txt"
  local flatpak_file="$package_dir/flatpak.txt"

  if [[ -f "$pacman_file" ]]; then
    echo "📦 Installing packages from $pacman_file..."
    mapfile -t pacman_packages <"$pacman_file"
    if ((${#pacman_packages[@]} > 0)); then
      yay -S --needed --noconfirm "${pacman_packages[@]}"
    else
      echo "⚠ pacman.txt exists but is empty, skipping"
    fi
  else
    echo "⚠ No pacman.txt found at $pacman_file, skipping"
  fi

  if [[ -f "$flatpak_file" ]]; then
    ensure_flatpak
    echo "📦 Installing Flatpak packages from $flatpak_file..."
    mapfile -t flatpak_packages <"$flatpak_file"
    if ((${#flatpak_packages[@]} > 0)); then
      for pkg in "${flatpak_packages[@]}"; do
        flatpak install -y flathub "$pkg"
      done
    else
      echo "⚠ flatpak.txt exists but is empty, skipping"
    fi
  else
    echo "⚠ No flatpak.txt found at $flatpak_file, skipping"
  fi
}

# --------------------------------------------------
# Install Starship prompt
# --------------------------------------------------
install_starship() {
  if command -v starship >/dev/null 2>&1; then
    echo "✓ starship already installed"
    return 0
  fi

  if ! command -v curl >/dev/null 2>&1; then
    echo "✗ curl is required to install starship"
    exit 1
  fi

  echo "🚀 Installing starship..."
  curl -sS https://starship.rs/install.sh | sh -s -- -y

  echo "✓ starship installed"
}

# --------------------------------------------------
# Install Nerd Font: FiraCode
# --------------------------------------------------
install_nerd_font() {
  local tmpdir

  echo "🔤 Installing Nerd Font: FiraCode..."

  if command -v fc-list >/dev/null 2>&1 && fc-list | grep -qi "FiraCode Nerd Font"; then
    echo "✓ FiraCode Nerd Font already installed"
    return 0
  fi

  tmpdir="$(mktemp -d)"
  git clone --depth 1 https://github.com/ryanoasis/nerd-fonts.git "$tmpdir/nerd-fonts"
  pushd "$tmpdir/nerd-fonts" >/dev/null
  ./install.sh FiraCode
  popd >/dev/null
  rm -rf "$tmpdir"

  if command -v fc-cache >/dev/null 2>&1; then
    fc-cache -fv >/dev/null 2>&1 || true
  fi

  echo "✓ FiraCode Nerd Font installed"
}

# --------------------------------------------------
# Set default user environment
# - PATH
# - editor / terminal
# - file manager / browser / mail client
# --------------------------------------------------
set_user_environment_defaults() {
  echo "🌱 Setting user environment defaults..."

  mkdir -p "$HOME/.config/environment.d"
  mkdir -p "$HOME/.local/bin"

  cat >"$HOME/.config/environment.d/path.conf" <<EOF
PATH=$HOME/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/bin
EOF

  cat >"$HOME/.config/environment.d/defaults.conf" <<EOF
EDITOR=nvim
VISUAL=nvim
TERMINAL=alacritty
EOF

  if command -v alacritty >/dev/null 2>&1; then
    cat >"$HOME/.local/bin/xdg-terminal-exec" <<'EOF'
#!/usr/bin/env bash
exec alacritty "$@"
EOF
    chmod +x "$HOME/.local/bin/xdg-terminal-exec"
    echo "✓ xdg-terminal-exec configured"
  else
    echo "⚠ alacritty not found, skipping terminal binding"
  fi

  if command -v nvim >/dev/null 2>&1; then
    git config --global core.editor "nvim"
    git config --global sequence.editor "nvim"
    echo "✓ Git editor set to nvim"
  else
    echo "⚠ nvim not found, skipping git editor config"
  fi

  if command -v xdg-mime >/dev/null 2>&1 && command -v xdg-settings >/dev/null 2>&1; then
    if [[ -f /usr/share/applications/org.kde.dolphin.desktop ]]; then
      xdg-mime default org.kde.dolphin.desktop inode/directory
      echo "✓ Default file manager set to Dolphin"
    else
      echo "⚠ Dolphin desktop entry not found, skipping file manager default"
    fi

    if [[ -f /usr/share/applications/firefox.desktop ]]; then
      xdg-settings set default-web-browser firefox.desktop || true
      xdg-mime default firefox.desktop x-scheme-handler/http
      xdg-mime default firefox.desktop x-scheme-handler/https
      xdg-mime default firefox.desktop text/html
      echo "✓ Default browser set to Firefox"
    else
      echo "⚠ Firefox desktop entry not found, skipping browser default"
    fi

    if [[ -f /usr/share/applications/thunderbird.desktop ]]; then
      xdg-mime default thunderbird.desktop x-scheme-handler/mailto
      xdg-mime default thunderbird.desktop message/rfc822
      echo "✓ Default mail client set to Thunderbird"
    else
      echo "⚠ Thunderbird desktop entry not found, skipping mail client default"
    fi
  else
    echo "⚠ xdg tools not found, skipping default app associations"
  fi

  echo "✓ Environment defaults configured"
}

# --------------------------------------------------
# Install and enable package export service/timer
# --------------------------------------------------
setup_package_export() {
  echo "⚙ Setting up package export service and timer..."

  mkdir -p "$HOME/.config/systemd/user"
  cp "$REPO_ROOT/systemd/package-export.service" "$HOME/.config/systemd/user/"
  cp "$REPO_ROOT/systemd/package-export.timer" "$HOME/.config/systemd/user/"

  systemctl --user daemon-reload
  systemctl --user enable --now package-export.timer
  systemctl --user start package-export.service || true

  echo "✓ package export service and timer configured"
}

# --------------------------------------------------
# Install and enable shared system update service/timer
# --------------------------------------------------
setup_system_update() {
  echo "⚙ Setting up system update service and timer..."

  mkdir -p "$HOME/.config/systemd/user"
  cp "$REPO_ROOT/systemd/system-update.service" "$HOME/.config/systemd/user/"
  cp "$REPO_ROOT/systemd/system-update.timer" "$HOME/.config/systemd/user/"

  systemctl --user daemon-reload
  systemctl --user enable --now system-update.timer

  echo "✓ system-update.timer enabled"
}

# --------------------------------------------------
# Install and enable shared monitoring services/timers
# - disk-space-check
# - heartbeat
# --------------------------------------------------
setup_shared_monitoring() {
  echo "⚙ Setting up shared monitoring services and timers..."

  mkdir -p "$HOME/.config/systemd/user"

  cp "$REPO_ROOT/systemd/disk-space-check.service" "$HOME/.config/systemd/user/"
  cp "$REPO_ROOT/systemd/disk-space-check.timer" "$HOME/.config/systemd/user/"
  cp "$REPO_ROOT/systemd/heartbeat.service" "$HOME/.config/systemd/user/"
  cp "$REPO_ROOT/systemd/heartbeat.timer" "$HOME/.config/systemd/user/"

  systemctl --user daemon-reload
  systemctl --user enable --now disk-space-check.timer
  systemctl --user enable --now heartbeat.timer

  echo "✓ Shared monitoring timers enabled"
}

# --------------------------------------------------
# Install and enable Timeshift snapshot service/timer
# - Arch workstations only
# --------------------------------------------------
setup_timeshift_snapshot() {
  echo "⚙ Setting up Timeshift snapshot service and timer..."

  mkdir -p "$HOME/.config/systemd/user"

  cp "$REPO_ROOT/systemd/timeshift-snapshot.service" "$HOME/.config/systemd/user/"
  cp "$REPO_ROOT/systemd/timeshift-snapshot.timer" "$HOME/.config/systemd/user/"

  systemctl --user daemon-reload
  systemctl --user enable --now timeshift-snapshot.timer

  echo "✓ Timeshift snapshot timer enabled"
}

# --------------------------------------------------
# Install and enable git monitoring services/timers
# --------------------------------------------------
setup_git_monitoring() {
  echo "⚙ Setting up git monitoring services and timers..."

  mkdir -p "$HOME/.config/systemd/user"
  cp "$REPO_ROOT/systemd/repo-update-check.service" "$HOME/.config/systemd/user/"
  cp "$REPO_ROOT/systemd/repo-update-check.timer" "$HOME/.config/systemd/user/"
  cp "$REPO_ROOT/systemd/dotfiles-change-check.service" "$HOME/.config/systemd/user/"
  cp "$REPO_ROOT/systemd/dotfiles-change-check.timer" "$HOME/.config/systemd/user/"

  systemctl --user daemon-reload
  systemctl --user enable --now repo-update-check.timer
  systemctl --user enable --now dotfiles-change-check.timer

  echo "✓ Git monitoring timers enabled"
}

# --------------------------------------------------
# Prepare shell dotfiles for stow
# - back up regular files
# - leave symlinks alone
# --------------------------------------------------
prepare_shell_dotfiles() {
  local backup_dir="$HOME/.dotfile-backups/$(date +%Y%m%d-%H%M%S)"
  local files=("$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.bash_logout")

  echo "🐚 Preparing shell dotfiles for stow..."

  for file in "${files[@]}"; do
    if [[ -L "$file" ]]; then
      echo "✓ $file is already a symlink, leaving it alone"
    elif [[ -f "$file" ]]; then
      mkdir -p "$backup_dir"
      mv "$file" "$backup_dir/"
      echo "✓ Backed up $(basename "$file") to $backup_dir"
    else
      echo "• $file not present, nothing to do"
    fi
  done
}

# --------------------------------------------------
# Apply general dotfiles via stow
# --------------------------------------------------
apply_general_dotfiles() {
  echo "🔗 Applying general dotfiles..."
  "$REPO_ROOT/scripts/stow-all.sh"
}

# --------------------------------------------------
# Apply host-specific environment overrides
# --------------------------------------------------
apply_host_environment() {
  local host_dir="$REPO_ROOT/hosts/$EXPECTED_MACHINE/$EXPECTED_OS"

  if [[ ! -d "$host_dir" ]]; then
    echo "⚠ No host-specific environment found at $host_dir, skipping"
    return 0
  fi

  echo "🌱 Applying host-specific environment from $host_dir..."

  for dir in "$host_dir"/*; do
    if [[ -d "$dir" ]]; then
      local name
      name="$(basename "$dir")"
      echo "🔗 Stowing host package: $name"
      stow -d "$host_dir" -t "$HOME" "$name"
    fi
  done
}

# --------------------------------------------------
# Run initial package export
# --------------------------------------------------
run_package_export() {
  echo "📝 Exporting current package state..."
  "$REPO_ROOT/scripts/package-export.sh"
}

# --------------------------------------------------
# Display final summary
# --------------------------------------------------
show_summary() {
  local git_name git_email local_ip

  git_name="$(git config --global user.name || echo "unset")"
  git_email="$(git config --global user.email || echo "unset")"
  local_ip="$( (ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") {print $(i+1); exit}}') || true)"
  local_ip="${local_ip:-unavailable}"

  echo
  echo "=================================================="
  echo "✓ Bootstrap complete for $MACHINE_LABEL ($EXPECTED_MACHINE)"
  echo "=================================================="
  echo

  if command -v fastfetch >/dev/null 2>&1; then
    fastfetch
    echo
  fi

  echo "Git user:"
  echo "  Name:  $git_name"
  echo "  Email: $git_email"
  echo
  echo "Local IP:"
  echo "  $local_ip"
  echo
}

# --------------------------------------------------
# Prompt for reboot
# --------------------------------------------------
prompt_reboot() {
  echo "Press Enter to reboot..."
  read -r
  sudo reboot
}

# --------------------------------------------------
# Main bootstrap flow
# --------------------------------------------------
main() {
  echo "🚀 Starting bootstrap for $MACHINE_LABEL ($EXPECTED_MACHINE)..."
  echo

  verify_machine_id
  verify_os
  enable_multilib
  initial_update
  ensure_yay
  install_packages
  install_starship
  install_nerd_font
  set_user_environment_defaults
  setup_package_export
  setup_system_update
  setup_git_monitoring
  setup_shared_monitoring
  setup_timeshift_snapshot
  prepare_shell_dotfiles
  apply_general_dotfiles
  apply_host_environment
  run_package_export
  show_summary

  echo
  echo "📊 Services configured:"
  echo "   - package-export        → state tracking (runs now + daily)"
  echo "   - system-update         → system maintenance (scheduled)"
  echo "   - repo-update-check     → remote update awareness (daily)"
  echo "   - dotfiles-change-check → local dotfiles drift awareness (daily)"
  echo "   - disk-space-check      → local disk usage warning (daily)"
  echo "   - heartbeat             → device online signal (daily)"
  echo "   - timeshift-snapshot    → weekly rollback snapshot"
  echo

  prompt_reboot
}

main "$@"
