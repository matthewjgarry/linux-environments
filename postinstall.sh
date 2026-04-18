#!/bin/bash
#
# Post install helper for Arch (GNOME base assumed).
#
# Vibe coded with the help of Cursor
#
# Style intentionally kept close to archInstaller.sh:
# - straightforward flow
# - heredoc package lists
# - simple prompts/menus
#
set -eu -o pipefail

SKIP_DOTFILES=0
SKIP_STOW=0

# Dotfiles defaults (same idea as original script)
DEFAULT_DOTFILES_REPO="https://github.com/matthewjgarry/My_dotfiles"
DEFAULT_DOTFILES_DIR_NAME="dotfiles"

: "${DOTFILES_REPO:=$DEFAULT_DOTFILES_REPO}"
: "${DOTFILES_PATH:=$HOME/$DEFAULT_DOTFILES_DIR_NAME}"
: "${DOTFILES_BRANCH:=master}"

if [[ "${1:-}" == "--skip-dotfiles" ]]; then
  SKIP_DOTFILES=1
elif [[ "${1:-}" == "--skip-stow" ]]; then
  SKIP_STOW=1
elif [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  sed -n '1,40p' "$0"
  exit 0
fi

append_unique() {
  local item="$1"
  shift
  local -n arr_ref="$1"
  local existing
  for existing in "${arr_ref[@]:-}"; do
    [[ "$existing" == "$item" ]] && return 0
  done
  arr_ref+=("$item")
}

simple_toggle_menu() {
  local title="$1"
  local -n labels_ref="$2"
  local -n state_ref="$3"
  local i mark choice idx

  while true; do
    echo ""
    echo "${title}"
    echo "(number=toggle, a=all, n=none, d=done)"
    for i in "${!labels_ref[@]}"; do
      mark="[ ]"
      [[ "${state_ref[$i]}" -eq 1 ]] && mark="[x]"
      printf "  %2d) %s %s\n" "$((i + 1))" "$mark" "${labels_ref[$i]}"
    done
    read -r -p "Choice: " choice
    choice="${choice,,}"

    case "$choice" in
      d|done|"") break ;;
      a|all)
        for i in "${!state_ref[@]}"; do state_ref[$i]=1; done
        ;;
      n|none)
        for i in "${!state_ref[@]}"; do state_ref[$i]=0; done
        ;;
      *)
        if [[ "$choice" =~ ^[0-9]+$ ]]; then
          idx=$((10#$choice - 1))
          if [[ "$idx" -ge 0 && "$idx" -lt "${#labels_ref[@]}" ]]; then
            if [[ "${state_ref[$idx]}" -eq 1 ]]; then
              state_ref[$idx]=0
            else
              state_ref[$idx]=1
            fi
          else
            echo "Invalid number: $choice"
          fi
        else
          echo "Unknown choice: $choice"
        fi
        ;;
    esac
  done
}

ensure_prereqs() {
  [[ -f /etc/arch-release ]] || { echo "This script is for Arch Linux."; exit 1; }
  command -v sudo >/dev/null 2>&1 || { echo "sudo is required."; exit 1; }

  sudo -n true 2>/dev/null || {
    echo "This script needs sudo access."
    sudo -v
  }
}

enable_multilib() {
  echo "Enabling multilib repo (if needed)..."
  sudo sed -i '/\[multilib\]/,/Include/ s/^#//' /etc/pacman.conf
}

update_system() {
  echo "Updating system packages..."
  sudo pacman -Syu --noconfirm
}

ensure_yay() {
  if command -v yay >/dev/null 2>&1; then
    return 0
  fi

  echo "Installing yay AUR helper..."
  sudo pacman -S --needed --noconfirm base-devel git

  if [[ -d "$HOME/yay/.git" ]]; then
    git -C "$HOME/yay" pull --ff-only
  else
    git clone https://aur.archlinux.org/yay.git "$HOME/yay"
  fi

  pushd "$HOME/yay" >/dev/null
  makepkg -si --noconfirm
  popd >/dev/null
}

select_machine() {
  local answer=""
  while [[ -z "$answer" ]]; do
    read -r -p "Is this desktop or laptop? [desktop/laptop]: " answer
    answer="${answer,,}"
    case "$answer" in
      desktop|laptop) ;;
      *) answer="" ;;
    esac
  done
  MACHINE_TYPE="$answer"
}

configure_git_identity() {
  local git_name git_email
  echo ""
  echo "Configure git identity"
  read -r -p "Git user.name: " git_name
  read -r -p "Git user.email: " git_email

  if [[ -n "${git_name// }" ]]; then
    git config --global user.name "$git_name"
  fi
  if [[ -n "${git_email// }" ]]; then
    git config --global user.email "$git_email"
  fi
}

# --- Main package selections --------------------------------------------------

declare -a PACMAN_PKGS=()
declare -a AUR_PKGS=()
declare -a STOW_DIRS=()

while read -r p; do
  [[ -n "$p" ]] || continue
  append_unique "$p" PACMAN_PKGS
done < <(
  cat <<'EOF_DEFAULT_PACMAN'
dolphin
archlinux-xdg-menu
stow
alacritty
starship
sl
fzf
neovim
xclip
tmux
tree
libxcrypt-compat
hyprland
hyprpaper
wofi
waybar
pipewire-alsa
pipewire-pulse
wireplumber
pavucontrol
fastfetch
bashtop
cmatrix
EOF_DEFAULT_PACMAN
)

# Default stow targets (close to original archInstaller style)
while read -r s; do
  [[ -n "$s" ]] || continue
  append_unique "$s" STOW_DIRS
done < <(
  cat <<'EOF_DEFAULT_STOW'
alacritty
starship
bash
neovim
tmux
wofi
waybar
bashtop
EOF_DEFAULT_STOW
)

# Optional apps toggle list
# format: label|pkg|source(pacman/aur)|stow_dir(optional)
declare -a OPTIONAL_ITEMS=(
  "VLC|vlc|pacman|"
  "Discord|discord|pacman|"
  "Thunderbird|thunderbird|pacman|thunderbird"
  "Firefox|firefox|pacman|"
  "LibreOffice|libreoffice-fresh|pacman|libreoffice"
  "qBittorrent|qbittorrent|pacman|"
  "FreeCAD|freecad|pacman|"
  "Steam|steam|pacman|"
  "Heroic Games Launcher|heroic-games-launcher-bin|aur|"
  "GIMP|gimp|pacman|gimp"
  "Inkscape|inkscape|pacman|inkscape"
  "OrcaSlicer|orca-slicer|pacman|"
  "Cursor|cursor-bin|aur|"
  "Helm|helm|pacman|"
  "Syncthing|syncthing|pacman|"
  "Stellarium|stellarium|pacman|"
  "Talosctl|talosctl-bin|aur|"
  "kubectl-bin|kubectl-bin|aur|"
  "Plex Desktop|plex-desktop|aur|"
)

declare -a OPTIONAL_LABELS=()
declare -a OPTIONAL_ON=()
for row in "${OPTIONAL_ITEMS[@]}"; do
  IFS='|' read -r label _pkg _src _stow <<<"$row"
  OPTIONAL_LABELS+=("$label")
  OPTIONAL_ON+=(0)
done

simple_toggle_menu "Optional app installs" OPTIONAL_LABELS OPTIONAL_ON

for i in "${!OPTIONAL_ITEMS[@]}"; do
  [[ "${OPTIONAL_ON[$i]}" -eq 1 ]] || continue
  IFS='|' read -r _label pkg src stow_dir <<<"${OPTIONAL_ITEMS[$i]}"
  if [[ "$src" == "aur" ]]; then
    append_unique "$pkg" AUR_PKGS
  else
    append_unique "$pkg" PACMAN_PKGS
  fi
  if [[ -n "$stow_dir" ]]; then
    append_unique "$stow_dir" STOW_DIRS
  fi
done

# Nerd font toggle list (multi-select)
# Uses nerd-fonts repo install.sh (not pacman packages)
declare -a NERD_ITEMS=(
  "FiraCode|FiraCode"
  "JetBrainsMono|JetBrainsMono"
  "Hack|Hack"
  "Meslo|Meslo"
  "SourceCodePro|SourceCodePro"
  "UbuntuMono|UbuntuMono"
  "Ubuntu|Ubuntu"
  "CascadiaMono|CascadiaMono"
  "CascadiaCode|CascadiaCode"
  "DejaVu|DejaVuSansMono"
)

declare -a NERD_LABELS=()
declare -a NERD_ON=()
declare -a NERD_SELECTED=()
for row in "${NERD_ITEMS[@]}"; do
  IFS='|' read -r label _pkg <<<"$row"
  NERD_LABELS+=("$label")
  NERD_ON+=(0)
done

simple_toggle_menu "Nerd Fonts (select all you want)" NERD_LABELS NERD_ON

for i in "${!NERD_ITEMS[@]}"; do
  [[ "${NERD_ON[$i]}" -eq 1 ]] || continue
  IFS='|' read -r _label font_name <<<"${NERD_ITEMS[$i]}"
  append_unique "$font_name" NERD_SELECTED
done

# Desktop/laptop branch requested
MACHINE_TYPE=""
select_machine
if [[ "$MACHINE_TYPE" == "desktop" ]]; then
  append_unique "hyprdesk" STOW_DIRS
else
  append_unique "linux-headers" PACMAN_PKGS
  append_unique "displaylink" AUR_PKGS
  append_unique "hyprtop" STOW_DIRS
fi

# --- Install phase ------------------------------------------------------------

echo ""
echo "Installing pacman packages..."
if [[ "${#PACMAN_PKGS[@]}" -gt 0 ]]; then
  sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"
fi

echo ""
ensure_yay

if [[ "${#AUR_PKGS[@]}" -gt 0 ]]; then
  echo "Installing AUR packages..."
  yay -S --needed --noconfirm "${AUR_PKGS[@]}"
fi

if [[ "${#NERD_SELECTED[@]}" -gt 0 ]]; then
  echo "Installing Nerd Fonts from nerd-fonts/install.sh..."
  if [[ ! -d "$HOME/nerd-fonts/.git" ]]; then
    git clone --depth 1 https://github.com/ryanoasis/nerd-fonts.git "$HOME/nerd-fonts"
  else
    git -C "$HOME/nerd-fonts" pull --ff-only
  fi

  (
    cd "$HOME/nerd-fonts"
    for nf in "${NERD_SELECTED[@]}"; do
      ./install.sh "$nf"
    done
  )
  fc-cache -fv
fi

# Enable displaylink only when selected
if printf '%s\n' "${AUR_PKGS[@]:-}" | grep -qx 'displaylink'; then
  echo "Enabling displaylink service..."
  sudo systemctl enable --now displaylink.service
fi

configure_git_identity

# --- Dotfiles + stow ----------------------------------------------------------

if [[ "$SKIP_DOTFILES" -eq 0 ]]; then
  echo ""
  echo "Cloning/updating dotfiles..."

  if [[ -d "$DOTFILES_PATH/.git" ]]; then
    git -C "$DOTFILES_PATH" pull --ff-only
  else
    mkdir -p "$(dirname "$DOTFILES_PATH")"
    git clone --branch "$DOTFILES_BRANCH" "$DOTFILES_REPO" "$DOTFILES_PATH" || git clone "$DOTFILES_REPO" "$DOTFILES_PATH"
  fi
fi

if [[ "$SKIP_STOW" -eq 0 && -d "$DOTFILES_PATH" ]]; then
  echo ""
  echo "Stow selections (from defaults + menu + profile):"
  printf '  %s\n' "${STOW_DIRS[@]}"

  (
    cd "$DOTFILES_PATH"
    # Only stow dirs that exist in dotfiles repo
    for d in "${STOW_DIRS[@]}"; do
      stow_dir="$d"
      # Handle common naming mismatch for Neovim stow package.
      if [[ "$d" == "nvim" && -d "neovim" ]]; then
        stow_dir="neovim"
      elif [[ "$d" == "neovim" && -d "nvim" ]]; then
        stow_dir="nvim"
      fi

      if [[ -d "$stow_dir" ]]; then
        stow "$stow_dir"
      else
        echo "Skipping missing stow dir: $d"
      fi
    done
  )
fi

# --- Done ---------------------------------------------------------------------

echo ""
echo "##############################"
echo "Setup complete"
echo "##############################"
fastfetch || true

echo ""
echo "Press Enter to restart the system when you are ready."
read -r
sudo reboot
