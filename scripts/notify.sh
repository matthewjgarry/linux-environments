#!/usr/bin/env bash

set -euo pipefail

WEBHOOK_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/discord-webhook"
MACHINE_ID_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/machine-id"

TITLE="${1:-Notification}"
MESSAGE="${2:-No message provided}"
LEVEL="${3:-info}"

# --------------------------------------------------
# Resolve machine identity
# --------------------------------------------------
if [[ -f "$MACHINE_ID_FILE" ]]; then
  MACHINE_ID="$(<"$MACHINE_ID_FILE")"
else
  MACHINE_ID="unknown-machine"
fi

HOSTNAME_SHORT="$(hostname 2>/dev/null || echo unknown-host)"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

# --------------------------------------------------
# Skip cleanly if webhook is not configured
# --------------------------------------------------
if [[ ! -f "$WEBHOOK_FILE" ]]; then
  echo "[notify] No webhook configured, skipping notification"
  exit 0
fi

WEBHOOK_URL="$(<"$WEBHOOK_FILE")"

if [[ -z "$WEBHOOK_URL" ]]; then
  echo "[notify] Webhook file is empty, skipping notification"
  exit 0
fi

# --------------------------------------------------
# Set severity styling
# --------------------------------------------------
case "$LEVEL" in
success)
  ICON="✅"
  COLOR=5763719
  LEVEL_LABEL="SUCCESS"
  ;;
warning)
  ICON="⚠️"
  COLOR=16705372
  LEVEL_LABEL="WARNING"
  ;;
error)
  ICON="❌"
  COLOR=15548997
  LEVEL_LABEL="ERROR"
  ;;
info | *)
  ICON="ℹ️"
  COLOR=3447003
  LEVEL_LABEL="INFO"
  ;;
esac

DISPLAY_TITLE="$ICON $TITLE"

# --------------------------------------------------
# Escape text safely for JSON
# --------------------------------------------------
json_escape() {
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
  else
    sed ':a;N;$!ba;s/\\/\\\\/g;s/"/\\"/g;s/\n/\\n/g' | awk '{print "\"" $0 "\""}'
  fi
}

ESCAPED_TITLE="$(printf '%s' "$DISPLAY_TITLE" | json_escape)"
ESCAPED_MESSAGE="$(printf '%s' "$MESSAGE" | json_escape)"
ESCAPED_MACHINE="$(printf '%s' "$MACHINE_ID" | json_escape)"
ESCAPED_HOST="$(printf '%s' "$HOSTNAME_SHORT" | json_escape)"
ESCAPED_TIME="$(printf '%s' "$TIMESTAMP" | json_escape)"
ESCAPED_FOOTER="$(printf '%s' "wormlogic homelab • $LEVEL_LABEL" | json_escape)"

# --------------------------------------------------
# Build Discord embed payload
# --------------------------------------------------
payload=$(
  cat <<EOF
{
  "embeds": [
    {
      "title": $ESCAPED_TITLE,
      "description": $ESCAPED_MESSAGE,
      "color": $COLOR,
      "fields": [
        {
          "name": "Machine",
          "value": $ESCAPED_MACHINE,
          "inline": true
        },
        {
          "name": "Host",
          "value": $ESCAPED_HOST,
          "inline": true
        },
        {
          "name": "Time",
          "value": $ESCAPED_TIME,
          "inline": false
        }
      ],
      "footer": {
        "text": $ESCAPED_FOOTER
      }
    }
  ]
}
EOF
)

# --------------------------------------------------
# Send notification
# --------------------------------------------------
curl -sS \
  -H "Content-Type: application/json" \
  -X POST \
  -d "$payload" \
  "$WEBHOOK_URL" >/dev/null

echo "[notify] Sent $LEVEL notification for $MACHINE_ID ($HOSTNAME_SHORT)"
