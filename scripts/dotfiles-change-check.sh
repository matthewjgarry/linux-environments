#!/usr/bin/env bash

set -euo pipefail

LOG_PREFIX="[dotfiles-change-check]"
REPO_DIR="$HOME/dotfiles"

if [[ ! -d "$REPO_DIR/.git" ]]; then
  echo "$LOG_PREFIX dotfiles repo not found at $REPO_DIR"
  exit 1
fi

cd "$REPO_DIR"

if git diff --quiet && git diff --cached --quiet && [[ -z "$(git ls-files --others --exclude-standard)" ]]; then
  echo "$LOG_PREFIX No change"
  exit 0
fi

echo "$LOG_PREFIX Local changes detected in dotfiles"
status_output="$(git status --short)"
echo "$status_output"

"$HOME/dotfiles/scripts/notify.sh" \
  "Dotfiles Changed" \
  "Local changes detected in ~/dotfiles on $(hostname):\n$status_output"
