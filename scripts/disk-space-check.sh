#!/usr/bin/env bash

set -euo pipefail

LOG_PREFIX="[disk-space-check]"
THRESHOLD="${1:-85}"

root_use="$(df / --output=pcent | tail -n 1 | tr -dc '0-9')"

echo "$LOG_PREFIX Root usage: ${root_use}%"

if ((root_use >= THRESHOLD)); then
  "$HOME/dotfiles/scripts/notify.sh" \
    "Disk Space Warning" \
    "Root filesystem on $(hostname) is at ${root_use}% usage."
fi
