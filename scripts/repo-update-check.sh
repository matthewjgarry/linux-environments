#!/usr/bin/env bash

set -euo pipefail

LOG_PREFIX="[repo-update-check]"
ROOT_DIR="$HOME"

echo "$LOG_PREFIX Checking git repositories under $ROOT_DIR..."

notify_needed=0
notify_body=""

find "$ROOT_DIR" -maxdepth 3 -type d -name ".git" 2>/dev/null | while read -r gitdir; do
  repo="${gitdir%/.git}"

  echo "$LOG_PREFIX Checking $repo"
  git -C "$repo" fetch --quiet || {
    echo "$LOG_PREFIX Failed to fetch $repo"
    continue
  }

  local_ref="$(git -C "$repo" rev-parse @ 2>/dev/null || true)"
  remote_ref="$(git -C "$repo" rev-parse @{u} 2>/dev/null || true)"
  base_ref="$(git -C "$repo" merge-base @ @{u} 2>/dev/null || true)"

  if [[ -z "$remote_ref" ]]; then
    echo "$LOG_PREFIX No upstream configured for $repo"
    continue
  fi

  if [[ "$local_ref" == "$remote_ref" ]]; then
    echo "$LOG_PREFIX Up to date: $repo"
  elif [[ "$local_ref" == "$base_ref" ]]; then
    echo "$LOG_PREFIX Behind remote: $repo"
    printf "Behind remote: %s\n" "$repo"
  elif [[ "$remote_ref" == "$base_ref" ]]; then
    echo "$LOG_PREFIX Ahead of remote: $repo"
    printf "Ahead of remote: %s\n" "$repo"
  else
    echo "$LOG_PREFIX Diverged: $repo"
    printf "Diverged: %s\n" "$repo"
  fi
done >/tmp/repo-update-check.out

cat /tmp/repo-update-check.out

if grep -Eq 'Behind remote:|Diverged:' /tmp/repo-update-check.out; then
  "$HOME/dotfiles/scripts/notify.sh" \
    "Repo Update Check" \
    "$(cat /tmp/repo-update-check.out)"
fi

rm -f /tmp/repo-update-check.out
