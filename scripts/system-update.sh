#!/usr/bin/env bash

set -euo pipefail

LOG_PREFIX="[system-update]"

echo "$LOG_PREFIX Starting system update..."

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
  echo "$LOG_PREFIX Unsupported system"
  exit 1
fi

echo "$LOG_PREFIX Distro: $DISTRO"

update_arch() {
  echo "$LOG_PREFIX Updating pacman packages..."
  sudo pacman -Syu --noconfirm

  if command -v flatpak >/dev/null 2>&1; then
    echo "$LOG_PREFIX Updating Flatpak packages..."
    flatpak update -y
  else
    echo "$LOG_PREFIX flatpak not present, skipping"
  fi
}

update_ubuntu() {
  echo "$LOG_PREFIX Updating apt packages..."
  sudo apt update
  sudo apt upgrade -y

  if command -v snap >/dev/null 2>&1; then
    echo "$LOG_PREFIX Refreshing snap packages..."
    sudo snap refresh
  else
    echo "$LOG_PREFIX snap not present, skipping"
  fi

  if command -v flatpak >/dev/null 2>&1; then
    echo "$LOG_PREFIX Updating Flatpak packages..."
    flatpak update -y
  else
    echo "$LOG_PREFIX flatpak not present, skipping"
  fi

  if command -v brew >/dev/null 2>&1; then
    echo "$LOG_PREFIX Updating Homebrew packages..."
    brew update
    brew upgrade
  else
    echo "$LOG_PREFIX brew not present, skipping"
  fi
}

case "$DISTRO" in
arch)
  update_arch
  ;;
ubuntu)
  update_ubuntu
  ;;
*)
  echo "$LOG_PREFIX Unsupported distro"
  exit 1
  ;;
esac

echo "$LOG_PREFIX System update complete"
