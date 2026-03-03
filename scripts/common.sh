#!/usr/bin/env bash

# --- Config loading ---
load_config() {
    local conf="${REMOTE_MAC_CONF:-$HOME/.remote-mac.conf}"
    if [ -f "$conf" ]; then
        # shellcheck source=/dev/null
        source "$conf"
    fi

    # Defaults (environment variables > config > default)
    MAC_SSH_HOST="${MAC_SSH_HOST:-mac.local}"
    MAC_SSH_USER="${MAC_SSH_USER:-$(whoami)}"
    MAC_SSH_PORT="${MAC_SSH_PORT:-22}"
    MAC_BRIDGE_URL="${MAC_BRIDGE_URL:-}"

    local control_root="${REMOTE_MAC_CONTROL_DIR:-}"
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
    local control_path="${control_root}/ssh_mac_%h"

    MAC_SSH="${MAC_SSH_USER}@${MAC_SSH_HOST}"
    local common_opts="-o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ControlMaster=auto -o ControlPath=${control_path} -o ControlPersist=10m"
    SSH_OPTS="-p ${MAC_SSH_PORT} ${common_opts}"
    SCP_OPTS="-P ${MAC_SSH_PORT} ${common_opts}"
}

shell_escape() {
    printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

json_escape() {
    python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" -- "$1"
}

now_ms() {
    python3 -c "import time; print(int(time.time()*1000))" 2>/dev/null || echo "0"
}
