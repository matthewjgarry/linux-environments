#!/usr/bin/env bash

set -e

echo "🔄 Updating system..."

if command -v pacman &>/dev/null; then
  echo "📦 Arch detected"
  sudo pacman -Syu --noconfirm
elif command -v apt &>/dev/null; then
  echo "📦 Ubuntu detected"
  sudo apt update && sudo apt upgrade -y
else
  echo "❌ Unsupported distro"
  exit 1
fi

echo "🧹 Cleaning up..."
if command -v pacman &>/dev/null; then
  sudo pacman -Sc --noconfirm
elif command -v apt &>/dev/null; then
  sudo apt autoremove -y
fi

echo "✅ Update complete"
