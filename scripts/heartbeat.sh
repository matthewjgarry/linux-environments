#!/usr/bin/env bash

set -euo pipefail

LOG_PREFIX="[heartbeat]"

echo "$LOG_PREFIX Sending heartbeat..."

"$HOME/dotfiles/scripts/notify.sh" \
  "Device Heartbeat" \
  "$(hostname) is online. User: $USER"
