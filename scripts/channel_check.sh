#!/usr/bin/env bash
# channel_check.sh — Check Mac connection channel status, output JSON
# Usage: channel_check.sh
#
# Config (env vars or ~/.remote-mac.conf):
#   MAC_SSH_HOST    — SSH host (default: mac.local)
#   MAC_SSH_USER    — SSH user (default: current user)
#   MAC_SSH_PORT    — SSH port (default: 22)
#   MAC_BRIDGE_URL  — Antigravity bridge health URL (optional)

set -euo pipefail

# --- Config loading ---
MAC_SSH_HOST="${MAC_SSH_HOST:-mac.local}"
MAC_SSH_USER="${MAC_SSH_USER:-$(whoami)}"
MAC_SSH_PORT="${MAC_SSH_PORT:-22}"
MAC_BRIDGE_URL="${MAC_BRIDGE_URL:-}"

conf="${REMOTE_MAC_CONF:-$HOME/.remote-mac.conf}"
if [ -f "$conf" ]; then
    # shellcheck source=/dev/null
    source "$conf"
fi

MAC_SSH="${MAC_SSH_USER}@${MAC_SSH_HOST}"

# Portable control socket directory (XDG_RUNTIME_DIR → TMPDIR → ~/.cache)
control_root="${REMOTE_MAC_CONTROL_DIR:-}"
if [ -z "$control_root" ]; then
    if [ -n "${XDG_RUNTIME_DIR:-}" ]; then
        control_root="${XDG_RUNTIME_DIR%/}/remote-mac"
    elif [ -n "${TMPDIR:-}" ]; then
        control_root="${TMPDIR%/}/remote-mac"
    else
        control_root="$HOME/.cache/remote-mac"
    fi
fi
mkdir -p "$control_root"
control_path="${control_root}/ssh_mac_%h"
SSH_OPTS="-p ${MAC_SSH_PORT} -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ControlMaster=auto -o ControlPath=${control_path} -o ControlPersist=10m"

now_ms() {
    python3 -c "import time; print(int(time.time()*1000))" 2>/dev/null || echo "0"
}

# Properly escape a string as a JSON value (handles quotes, backslashes, etc.)
json_escape() {
    python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" -- "$1"
}

# Check SSH
ssh_ok=false
ssh_start=$(now_ms)
if ssh $SSH_OPTS "$MAC_SSH" "echo ok" &>/dev/null 2>&1; then
    ssh_ok=true
fi
ssh_end=$(now_ms)
ssh_ms=$(( ssh_end - ssh_start ))

# Check AG Bridge (optional — only if MAC_BRIDGE_URL is set)
bridge_ok=false
bridge_status=""
bridge_ms=0
if [ -n "$MAC_BRIDGE_URL" ]; then
    bridge_start=$(now_ms)
    # Use -sSf so HTTP 4xx/5xx are treated as failures (bridge_ok stays false)
    bridge_resp=$(curl -sSf --max-time 3 "$MAC_BRIDGE_URL" 2>/dev/null || echo "")
    bridge_end=$(now_ms)
    bridge_ms=$(( bridge_end - bridge_start ))
    bridge_status=$(echo "$bridge_resp" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status','?'))" 2>/dev/null || echo "")
    if [ -n "$bridge_status" ]; then
        bridge_ok=true
    fi
fi

# Preferred channel
if [ "$ssh_ok" = true ]; then
    preferred="ssh"
else
    preferred="none"
fi

# Build JSON safely — avoid injection from dynamic values
timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u)
timestamp_json=$(json_escape "$timestamp")
target_json=$(json_escape "${MAC_SSH_USER}@${MAC_SSH_HOST}:${MAC_SSH_PORT}")
bridge_status_json=$(json_escape "$bridge_status")
preferred_json=$(json_escape "$preferred")

cat <<EOF
{
  "timestamp": ${timestamp_json},
  "ssh": {
    "available": $ssh_ok,
    "latency_ms": $ssh_ms,
    "target": ${target_json}
  },
  "ag_bridge": {
    "available": $bridge_ok,
    "latency_ms": $bridge_ms,
    "status": ${bridge_status_json}
  },
  "preferred": ${preferred_json}
}
EOF
