#!/usr/bin/env bash

set -euo pipefail

LOG_PREFIX="[timeshift-snapshot]"

if ! command -v timeshift >/dev/null 2>&1; then
  echo "$LOG_PREFIX timeshift not installed, skipping"
  exit 0
fi

echo "$LOG_PREFIX Creating Timeshift snapshot..."
sudo timeshift --create --comments "scheduled snapshot" --tags W

echo "$LOG_PREFIX Snapshot complete"
