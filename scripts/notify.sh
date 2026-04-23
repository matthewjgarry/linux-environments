#!/usr/bin/env bash
set -euo pipefail

WEBHOOK_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/discord-webhook"
N8N_WEBHOOK_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/n8n-webhook"
MACHINE_ID_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/machine-id"

TITLE="${1:-Notification}"
MESSAGE="${2:-No message provided}"
LEVEL="${3:-info}"
CHECK_NAME="${4:-notify}"

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
# Set severity styling
# --------------------------------------------------
case "$LEVEL" in
  success)
    ICON="✅"
    COLOR=5763719
    LEVEL_LABEL="SUCCESS"
    N8N_SEVERITY="ok"
    ;;
  warning)
    ICON="⚠️"
    COLOR=16705372
    LEVEL_LABEL="WARNING"
    N8N_SEVERITY="warning"
    ;;
  error)
    ICON="❌"
    COLOR=15548997
    LEVEL_LABEL="ERROR"
    N8N_SEVERITY="error"
    ;;
  info | *)
    ICON="ℹ️"
    COLOR=3447003
    LEVEL_LABEL="INFO"
    N8N_SEVERITY="info"
    ;;
esac

DISPLAY_TITLE="$ICON $TITLE"

# --------------------------------------------------
# Helpers
# --------------------------------------------------
json_escape() {
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
  else
    sed ':a;N;$!ba;s/\\/\\\\/g;s/"/\\"/g;s/\n/\\n/g' | awk '{print "\"" $0 "\""}'
  fi
}

post_discord() {
  local webhook_url="$1"

  local escaped_title escaped_message escaped_machine escaped_host escaped_time escaped_footer payload
  escaped_title="$(printf '%s' "$DISPLAY_TITLE" | json_escape)"
  escaped_message="$(printf '%s' "$MESSAGE" | json_escape)"
  escaped_machine="$(printf '%s' "$MACHINE_ID" | json_escape)"
  escaped_host="$(printf '%s' "$HOSTNAME_SHORT" | json_escape)"
  escaped_time="$(printf '%s' "$TIMESTAMP" | json_escape)"
  escaped_footer="$(printf '%s' "wormlogic homelab • $LEVEL_LABEL" | json_escape)"

  payload=$(cat <<EOF
{
  "embeds": [
    {
      "title": $escaped_title,
      "description": $escaped_message,
      "color": $COLOR,
      "fields": [
        { "name": "Machine ID", "value": $escaped_machine, "inline": true },
        { "name": "Hostname", "value": $escaped_host, "inline": true },
        { "name": "Time", "value": $escaped_time, "inline": false }
      ],
      "footer": { "text": $escaped_footer }
    }
  ]
}
EOF
)

  curl -sS -H "Content-Type: application/json" -X POST -d "$payload" "$webhook_url" >/dev/null
}

post_n8n() {
  local n8n_webhook_url="$1"

  local escaped_source escaped_machine escaped_host escaped_service escaped_check escaped_severity escaped_title escaped_message escaped_time payload
  escaped_source="$(printf '%s' "linux-environments" | json_escape)"
  escaped_machine="$(printf '%s' "$MACHINE_ID" | json_escape)"
  escaped_host="$(printf '%s' "$HOSTNAME_SHORT" | json_escape)"
  escaped_service="$(printf '%s' "host" | json_escape)"
  escaped_check="$(printf '%s' "$CHECK_NAME" | json_escape)"
  escaped_severity="$(printf '%s' "$N8N_SEVERITY" | json_escape)"
  escaped_title="$(printf '%s' "$TITLE" | json_escape)"
  escaped_message="$(printf '%s' "$MESSAGE" | json_escape)"
  escaped_time="$(printf '%s' "$TIMESTAMP" | json_escape)"

  payload=$(cat <<EOF
{
  "source": $escaped_source,
  "machine_id": $escaped_machine,
  "hostname": $escaped_host,
  "service": $escaped_service,
  "check_name": $escaped_check,
  "severity": $escaped_severity,
  "title": $escaped_title,
  "message": $escaped_message,
  "timestamp": $escaped_time
}
EOF
)

  curl -sS -H "Content-Type: application/json" -X POST -d "$payload" "$n8n_webhook_url" >/dev/null
}

# --------------------------------------------------
# Discord notification
# --------------------------------------------------
if [[ -f "$WEBHOOK_FILE" ]]; then
  WEBHOOK_URL="$(<"$WEBHOOK_FILE")"
  if [[ -n "$WEBHOOK_URL" ]]; then
    if post_discord "$WEBHOOK_URL"; then
      echo "[notify] Sent $LEVEL notification for $MACHINE_ID ($HOSTNAME_SHORT)"
    else
      echo "[notify] Failed to send Discord notification" >&2
    fi
  else
    echo "[notify] Discord webhook file is empty, skipping Discord notification"
  fi
else
  echo "[notify] No Discord webhook configured, skipping Discord notification"
fi

# --------------------------------------------------
# n8n event notification
# --------------------------------------------------
if [[ -f "$N8N_WEBHOOK_FILE" ]]; then
  N8N_WEBHOOK_URL="$(<"$N8N_WEBHOOK_FILE")"
  if [[ -n "$N8N_WEBHOOK_URL" ]]; then
    if post_n8n "$N8N_WEBHOOK_URL"; then
      echo "[notify] Sent n8n event for $MACHINE_ID ($HOSTNAME_SHORT)"
    else
      echo "[notify] Failed to send n8n event" >&2
    fi
  else
    echo "[notify] n8n webhook file is empty, skipping n8n event"
  fi
else
  echo "[notify] No n8n webhook configured, skipping n8n event"
fi
