#!/usr/bin/env bash

set -euo pipefail

# --------------------------------------------------
# Resolve repo root and machine identity file path
# --------------------------------------------------
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
MACHINE_ID_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/machine-id"
EXPECTED_MACHINE="${1:-laptop02}"
EXPECTED_OS="ubuntu"
MACHINE_LABEL="HP Envy"

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
  if ! command -v apt >/dev/null 2>&1; then
    echo "✗ Ubuntu bootstrap called on non-Ubuntu system"
    exit 1
  fi

  echo "✓ Operating system verified: $EXPECTED_OS"
}

# --------------------------------------------------
# Prepare Ubuntu repositories and architecture
# - add i386 architecture
# - enable multiverse
# - add qBittorrent stable PPA
# - perform initial update/upgrade before switching to nala
# --------------------------------------------------
prepare_ubuntu_repos() {
  echo "📦 Preparing Ubuntu repositories and architecture..."

  sudo apt update
  sudo apt install -y software-properties-common curl ca-certificates gnupg

  sudo dpkg --add-architecture i386 || true
  sudo add-apt-repository -y multiverse
  sudo add-apt-repository -y ppa:qbittorrent-team/qbittorrent-stable

  echo "🔄 Performing initial apt update/upgrade before switching to nala..."
  sudo apt update
  sudo apt upgrade -y

  echo "✓ Ubuntu repo preparation complete"
}

# --------------------------------------------------
# Ensure nala is available
# --------------------------------------------------
ensure_nala() {
  if command -v nala >/dev/null 2>&1; then
    echo "✓ nala is available"
    return 0
  fi

  echo "📦 nala not found. Installing nala..."
  sudo apt install -y nala
  echo "✓ nala installed"
}

# --------------------------------------------------
# Perform initial system update using nala
# --------------------------------------------------
initial_update() {
  echo "🔄 Performing nala update/upgrade..."
  sudo nala update
  sudo nala upgrade -y
}

# --------------------------------------------------
# Ensure Flatpak is available and Flathub is configured
# --------------------------------------------------
ensure_flatpak() {
  if ! command -v flatpak >/dev/null 2>&1; then
    echo "📦 flatpak not found. Installing flatpak..."
    sudo nala install -y flatpak
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
# Ensure snap is available
# --------------------------------------------------
ensure_snap() {
  if command -v snap >/dev/null 2>&1; then
    echo "✓ snap is available"
    return 0
  fi

  echo "📦 snap not found. Installing snapd..."
  sudo nala install -y snapd
  sudo systemctl enable --now snapd
  echo "✓ snapd installed and enabled"
}

wait_for_snap() {
  echo "⏳ Waiting for snapd to become ready..."

  # Ensure service is running
  sudo systemctl enable --now snapd

  # Wait until snap responds
  for i in {1..20}; do
    if snap version >/dev/null 2>&1; then
      echo "✓ snapd is ready"
      return 0
    fi
    sleep 1
  done

  echo "⚠ snapd did not become ready in time, continuing anyway"
}

# --------------------------------------------------
# Ensure Homebrew is available
# --------------------------------------------------
ensure_brew() {
  if command -v brew >/dev/null 2>&1; then
    echo "✓ Homebrew is available"
    return 0
  fi

  echo "📦 Homebrew not found. Installing Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  fi

  echo "✓ Homebrew installed"
}

# --------------------------------------------------
# Install kubectl into ~/.local/bin
# --------------------------------------------------
install_kubectl() {
  local arch
  local kubectl_arch
  local tmpdir

  if command -v kubectl >/dev/null 2>&1; then
    echo "✓ kubectl is already installed"
    return 0
  fi

  echo "☸ Installing kubectl..."

  arch="$(uname -m)"
  case "$arch" in
  x86_64) kubectl_arch="amd64" ;;
  aarch64 | arm64) kubectl_arch="arm64" ;;
  *)
    echo "⚠ Unsupported architecture for kubectl: $arch"
    return 0
    ;;
  esac

  mkdir -p "$HOME/.local/bin"
  tmpdir="$(mktemp -d)"

  pushd "$tmpdir" >/dev/null
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${kubectl_arch}/kubectl"
  chmod +x kubectl
  mv kubectl "$HOME/.local/bin/kubectl"
  popd >/dev/null

  rm -rf "$tmpdir"
  echo "✓ kubectl installed to ~/.local/bin"
}

# --------------------------------------------------
# Install Helm using official installer script
# --------------------------------------------------
install_helm() {
  local tmpdir

  if command -v helm >/dev/null 2>&1; then
    echo "✓ helm is already installed"
    return 0
  fi

  echo "⛵ Installing Helm..."
  tmpdir="$(mktemp -d)"
  pushd "$tmpdir" >/dev/null
  curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4
  chmod 700 get_helm.sh
  sudo ./get_helm.sh
  popd >/dev/null
  rm -rf "$tmpdir"

  echo "✓ helm installed"
}

# --------------------------------------------------
# Ensure package ecosystems are installed even if
# their package list files are absent
# --------------------------------------------------
ensure_package_ecosystems() {
  echo "🧩 Ensuring package ecosystems are installed..."
  ensure_snap
  ensure_flatpak
  ensure_brew
  install_kubectl
  install_helm
}

# --------------------------------------------------
# Install packages from machine-specific lists
# --------------------------------------------------
install_packages() {
  local package_dir="$REPO_ROOT/system/$EXPECTED_MACHINE/$EXPECTED_OS"
  local apt_file="$package_dir/apt.txt"
  local snap_file="$package_dir/snap.txt"
  local flatpak_file="$package_dir/flatpak.txt"
  local brew_file="$package_dir/brew.txt"

  # ----------------------------
  # APT / Nala packages
  # ----------------------------
  if [[ -f "$apt_file" ]]; then
    echo "📦 Installing packages from $apt_file..."
    mapfile -t apt_packages <"$apt_file"
    if ((${#apt_packages[@]} > 0)); then
      sudo nala install -y "${apt_packages[@]}"
    else
      echo "⚠ apt.txt exists but is empty, skipping"
    fi
  else
    echo "⚠ No apt.txt found at $apt_file, skipping"
  fi

  # ----------------------------
  # Snap packages
  # ----------------------------
  if [[ -f "$snap_file" ]]; then
    ensure_snap
    wait_for_snap

    echo "📦 Installing snap packages from $snap_file..."
    mapfile -t snap_packages <"$snap_file"
    if ((${#snap_packages[@]} > 0)); then
      for pkg in "${snap_packages[@]}"; do
        sudo snap install "$pkg"
      done
    else
      echo "⚠ snap.txt exists but is empty, skipping"
    fi
  else
    echo "⚠ No snap.txt found at $snap_file, skipping"
  fi

  # ----------------------------
  # Flatpak packages
  # ----------------------------
  if [[ -f "$flatpak_file" ]]; then
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

  # ----------------------------
  # Homebrew packages
  # ----------------------------
  if [[ -f "$brew_file" ]]; then
    if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
      eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi

    echo "📦 Installing Homebrew packages from $brew_file..."
    mapfile -t brew_packages <"$brew_file"
    if ((${#brew_packages[@]} > 0)); then
      brew update
      brew upgrade
      for pkg in "${brew_packages[@]}"; do
        brew install "$pkg" || true
      done
    else
      echo "⚠ brew.txt exists but is empty, skipping"
    fi
  else
    echo "⚠ No brew.txt found at $brew_file, skipping"
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
# - browser / mail client
# --------------------------------------------------
set_user_environment_defaults() {
  echo "🌱 Setting user environment defaults..."

  mkdir -p "$HOME/.config/environment.d"
  mkdir -p "$HOME/.local/bin"

  cat >"$HOME/.config/environment.d/path.conf" <<EOF
PATH=$HOME/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/bin:/bin
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
# Resolve desktop file if present
# --------------------------------------------------
find_desktop_entry() {
  local candidates=("$@")
  local candidate

  for candidate in "${candidates[@]}"; do
    if [[ -f "/usr/share/applications/$candidate" ]] || [[ -f "$HOME/.local/share/applications/$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done

  return 1
}

# --------------------------------------------------
# Apply GNOME environment settings that are not
# convenient to manage via stow
# --------------------------------------------------
apply_gnome_environment() {
  local wallpaper_path="$REPO_ROOT/wallpaper/1224149.png"
  local wallpaper_uri="file://$wallpaper_path"
  local firefox_entry thunderbird_entry discord_entry alacritty_entry plex_entry
  local favorites=()

  echo "🧩 Applying GNOME environment settings..."

  if ! command -v gsettings >/dev/null 2>&1; then
    echo "⚠ gsettings not found, skipping GNOME environment configuration"
    return 0
  fi

  # --------------------------------------------------
  # Theme / appearance
  # --------------------------------------------------
  gsettings set org.gnome.desktop.interface gtk-theme 'Yaru-magenta-dark'
  gsettings set org.gnome.desktop.interface icon-theme 'Yaru-magenta'
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
  gsettings set org.gnome.desktop.interface monospace-font-name 'FiraCode Nerd Font 11'
  gsettings set org.gnome.desktop.interface show-battery-percentage true

  # --------------------------------------------------
  # Night light
  # - automatic schedule (sunset to sunrise)
  # - approximate 30% tint via temperature
  # --------------------------------------------------
  gsettings set org.gnome.settings-daemon.plugins.color night-light-enabled true
  gsettings set org.gnome.settings-daemon.plugins.color night-light-schedule-automatic true
  gsettings set org.gnome.settings-daemon.plugins.color night-light-temperature uint32 3700

  # --------------------------------------------------
  # Dock position and icon size
  # --------------------------------------------------
  if gsettings writable org.gnome.shell.extensions.dash-to-dock dock-position >/dev/null 2>&1; then
    gsettings set org.gnome.shell.extensions.dash-to-dock dock-position 'BOTTOM'
    gsettings set org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 42
  fi

  # --------------------------------------------------
  # Favorites
  # --------------------------------------------------
  firefox_entry="$(find_desktop_entry firefox.desktop org.mozilla.firefox.desktop || true)"
  thunderbird_entry="$(find_desktop_entry thunderbird.desktop org.mozilla.Thunderbird.desktop || true)"
  discord_entry="$(find_desktop_entry discord.desktop com.discordapp.Discord.desktop || true)"
  alacritty_entry="$(find_desktop_entry Alacritty.desktop alacritty.desktop || true)"
  plex_entry="$(find_desktop_entry plex-desktop_plex-desktop.desktop || true)"

  [[ -n "${firefox_entry:-}" ]] && favorites+=("'$firefox_entry'")
  [[ -n "${thunderbird_entry:-}" ]] && favorites+=("'$thunderbird_entry'")
  [[ -n "${discord_entry:-}" ]] && favorites+=("'$discord_entry'")
  [[ -n "${alacritty_entry:-}" ]] && favorites+=("'$alacritty_entry'")
  [[ -n "${plex_entry:-}" ]] && favorites+=("'$plex_entry'")

  if ((${#favorites[@]} > 0)); then
    local joined
    joined="$(
      IFS=,
      echo "${favorites[*]}"
    )"
    gsettings set org.gnome.shell favorite-apps "[$joined]"
  fi

  # --------------------------------------------------
  # Wallpaper
  # --------------------------------------------------
  if [[ -f "$wallpaper_path" ]]; then
    gsettings set org.gnome.desktop.background picture-uri "$wallpaper_uri"
    gsettings set org.gnome.desktop.background picture-uri-dark "$wallpaper_uri" || true
    echo "✓ Wallpaper set to $wallpaper_path"
  else
    echo "⚠ Wallpaper not found at $wallpaper_path, skipping"
  fi

  echo "✓ GNOME environment configured"
}

# --------------------------------------------------
# Disable broken touchscreen persistently
# - requested specifically as xorg device 9
# - applied via user service and XDG autostart
# --------------------------------------------------
setup_touchscreen_disable() {
  echo "🖐 Configuring persistent touchscreen disable for Xorg device 9..."

  mkdir -p "$HOME/.local/bin"
  mkdir -p "$HOME/.config/systemd/user"
  mkdir -p "$HOME/.config/autostart"

  cat >"$HOME/.local/bin/disable-touchscreen.sh" <<'EOF'
#!/usr/bin/env bash
if command -v xinput >/dev/null 2>&1; then
    xinput disable 9 || true
fi
EOF
  chmod +x "$HOME/.local/bin/disable-touchscreen.sh"

  cat >"$HOME/.config/systemd/user/disable-touchscreen.service" <<'EOF'
[Unit]
Description=Disable broken touchscreen device 9 after graphical login
After=graphical-session.target
Wants=graphical-session.target

[Service]
Type=oneshot
ExecStart=%h/.local/bin/disable-touchscreen.sh

[Install]
WantedBy=default.target
EOF

  cat >"$HOME/.config/autostart/disable-touchscreen.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Disable Touchscreen
Exec=/bin/bash -lc "$HOME/.local/bin/disable-touchscreen.sh"
X-GNOME-Autostart-enabled=true
NoDisplay=false
Terminal=false
EOF

  systemctl --user daemon-reload
  systemctl --user enable disable-touchscreen.service
  "$HOME/.local/bin/disable-touchscreen.sh"

  echo "✓ Touchscreen disable service configured"
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

  if command -v neofetch >/dev/null 2>&1; then
    neofetch
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
# Main bootstrap flow
# --------------------------------------------------
main() {
  echo "🚀 Starting bootstrap for $MACHINE_LABEL ($EXPECTED_MACHINE)..."
  echo

  verify_machine_id
  verify_os
  prepare_ubuntu_repos
  ensure_nala
  initial_update
  ensure_package_ecosystems
  install_packages
  install_starship
  install_nerd_font
  set_user_environment_defaults
  apply_gnome_environment
  setup_touchscreen_disable
  setup_package_export
  setup_system_update
  setup_git_monitoring
  setup_shared_monitoring
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
  echo "   - disable-touchscreen   → disable Xorg device 9 at login"
  echo

  prompt_reboot
}

main "$@"
