#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MACHINE_ID_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/machine-id"
LOG_PREFIX="[package-export]"

echo "$LOG_PREFIX Starting package export..."

if [[ ! -f "$MACHINE_ID_FILE" ]]; then
  echo "$LOG_PREFIX Missing machine identity file: $MACHINE_ID_FILE"
  exit 1
fi

MACHINE_ID="$(<"$MACHINE_ID_FILE")"

if [[ -z "$MACHINE_ID" ]]; then
  echo "$LOG_PREFIX Machine identity file is empty: $MACHINE_ID_FILE"
  exit 1
fi

detect_distro() {
  if command -v pacman >/dev/null 2>&1; then
    echo "arch"
  elif command -v apt >/dev/null 2>&1; then
    echo "ubuntu"
  else
    echo "unsupported"
  fi
}

DISTRO="$(detect_distro)"

if [[ "$DISTRO" == "unsupported" ]]; then
  echo "$LOG_PREFIX Unsupported distro"
  exit 1
fi

TARGET_DIR="$REPO_ROOT/system/$MACHINE_ID/$DISTRO"

echo "$LOG_PREFIX Machine ID: $MACHINE_ID"
echo "$LOG_PREFIX Distro: $DISTRO"
echo "$LOG_PREFIX Target dir: $TARGET_DIR"

mkdir -p "$TARGET_DIR"

write_if_changed() {
  local tmpfile="$1"
  local outfile="$2"

  if [[ -f "$outfile" ]] && cmp -s "$tmpfile" "$outfile"; then
    echo "$LOG_PREFIX No change: $(basename "$outfile")"
    rm -f "$tmpfile"
    return 1
  fi

  mv "$tmpfile" "$outfile"
  echo "$LOG_PREFIX Updated: $(basename "$outfile")"
  return 0
}

remove_if_exists() {
  local outfile="$1"
  if [[ -f "$outfile" ]]; then
    rm -f "$outfile"
    echo "$LOG_PREFIX Removed stale file: $(basename "$outfile")"
  fi
}

export_arch_pacman() {
  pacman -Qqe | sort
}

export_ubuntu_apt() {
  apt-mark showmanual | sort
}

export_flatpak() {
  flatpak list --app --columns=application | sort
}

export_snap() {
  snap list | awk 'NR>1 {print $1}' | sort
}

export_brew() {
  brew list --formula | sort
}

changed=0

if [[ "$DISTRO" == "arch" ]]; then
  tmp_pacman="$(mktemp)"
  export_arch_pacman >"$tmp_pacman"
  if write_if_changed "$tmp_pacman" "$TARGET_DIR/pacman.txt"; then
    changed=1
  fi

  if command -v flatpak >/dev/null 2>&1; then
    tmp_flatpak="$(mktemp)"
    export_flatpak >"$tmp_flatpak"
    if write_if_changed "$tmp_flatpak" "$TARGET_DIR/flatpak.txt"; then
      changed=1
    fi
  else
    remove_if_exists "$TARGET_DIR/flatpak.txt"
  fi
fi

if [[ "$DISTRO" == "ubuntu" ]]; then
  tmp_apt="$(mktemp)"
  export_ubuntu_apt >"$tmp_apt"
  if write_if_changed "$tmp_apt" "$TARGET_DIR/apt.txt"; then
    changed=1
  fi

  if command -v snap >/dev/null 2>&1; then
    tmp_snap="$(mktemp)"
    export_snap >"$tmp_snap"
    if write_if_changed "$tmp_snap" "$TARGET_DIR/snap.txt"; then
      changed=1
    fi
  else
    remove_if_exists "$TARGET_DIR/snap.txt"
  fi

  if command -v flatpak >/dev/null 2>&1; then
    tmp_flatpak="$(mktemp)"
    export_flatpak >"$tmp_flatpak"
    if write_if_changed "$tmp_flatpak" "$TARGET_DIR/flatpak.txt"; then
      changed=1
    fi
  else
    remove_if_exists "$TARGET_DIR/flatpak.txt"
  fi

  if command -v brew >/dev/null 2>&1; then
    tmp_brew="$(mktemp)"
    export_brew >"$tmp_brew"
    if write_if_changed "$tmp_brew" "$TARGET_DIR/brew.txt"; then
      changed=1
    fi
  else
    remove_if_exists "$TARGET_DIR/brew.txt"
  fi
fi

if [[ "$changed" -eq 1 ]]; then
  "$REPO_ROOT/scripts/notify.sh" \
    "Package List Updated" \
    "Package state changed for $MACHINE_ID on $(hostname). Review and commit the updated files in $TARGET_DIR."
fi

echo "$LOG_PREFIX Package export complete"
