#!/usr/bin/env bash

set -euo pipefail

# --------------------------------------------------
# Resolve repo root and stow source directory
# --------------------------------------------------
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STOW_DIR="$REPO_ROOT/stow"
TARGET_DIR="$HOME"

# --------------------------------------------------
# Verify stow source directory exists
# --------------------------------------------------
if [[ ! -d "$STOW_DIR" ]]; then
  echo "❌ stow/ directory not found at $STOW_DIR"
  exit 1
fi

echo "🔗 Applying stow packages from $STOW_DIR to $TARGET_DIR..."

# --------------------------------------------------
# Stow each package directory found under stow/
# --------------------------------------------------
for dir in "$STOW_DIR"/*; do
  if [[ -d "$dir" ]]; then
    name="$(basename "$dir")"
    echo "🔗 Stowing $name..."
    stow -d "$STOW_DIR" -t "$TARGET_DIR" "$name"
  fi
done

echo "✅ Done"
