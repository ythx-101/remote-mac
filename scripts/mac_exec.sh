#!/usr/bin/env bash
# mac_exec.sh — Remote Mac control via SSH
# Usage:
#   mac_exec.sh --run "command" [timeout_seconds]
#   mac_exec.sh --screenshot [output_path]
#   mac_exec.sh --app "open|activate|quit|kill:AppName"
#   mac_exec.sh --file "get|put:src:dst"
#
# Config (env vars or ~/.remote-mac.conf):
#   MAC_SSH_HOST   — SSH host (default: mac.local)
#   MAC_SSH_USER   — SSH user (default: current user)
#   MAC_SSH_PORT   — SSH port (default: 22)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Config loading ---
load_config() {
    # Defaults
    MAC_SSH_HOST="${MAC_SSH_HOST:-mac.local}"
    MAC_SSH_USER="${MAC_SSH_USER:-$(whoami)}"
    MAC_SSH_PORT="${MAC_SSH_PORT:-22}"

    # Load from config file if present
    local conf="${REMOTE_MAC_CONF:-$HOME/.remote-mac.conf}"
    if [ -f "$conf" ]; then
        # shellcheck source=/dev/null
        source "$conf"
    fi

    # Portable control socket directory (XDG_RUNTIME_DIR → TMPDIR → ~/.cache)
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

# Safely single-quote a string for use in remote shell commands
shell_escape() {
    printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

load_config

# --- Channel Detection ---
check_ssh() {
    if ssh $SSH_OPTS "$MAC_SSH" "echo ok" &>/dev/null; then
        return 0
    fi
    return 1
}

exec_cmd() {
    local cmd="$1"
    if ! check_ssh; then
        echo '{"error":"Mac SSH unreachable"}' >&2
        exit 1
    fi
    ssh $SSH_OPTS "$MAC_SSH" "$cmd"
}

# --- Actions ---
do_run() {
    local cmd="$1"
    local tout="${2:-30}"
    echo "[ssh→mac] (timeout ${tout}s) $cmd" >&2
    # Shell-escape the command so it runs exactly once under bash -lc
    local cmd_payload
    cmd_payload=$(shell_escape "$cmd")
    local remote_cmd
    remote_cmd=$(cat <<EOF
if command -v gtimeout >/dev/null; then
    gtimeout ${tout} bash -lc ${cmd_payload}
elif command -v timeout >/dev/null; then
    timeout ${tout} bash -lc ${cmd_payload}
else
    bash -lc ${cmd_payload}
fi
EOF
)
    exec_cmd "$remote_cmd"
}

do_screenshot() {
    local local_path="${1:-/tmp/mac_screenshot.png}"
    local remote_path="/tmp/mac_ss_$$.png"
    echo "[screenshot] → $local_path" >&2

    if ! check_ssh; then
        echo '{"error":"SSH unreachable"}' >&2
        exit 1
    fi

    ssh $SSH_OPTS "$MAC_SSH" "/usr/sbin/screencapture -x $remote_path"
    scp $SCP_OPTS "$MAC_SSH:$remote_path" "$local_path"
    ssh $SSH_OPTS "$MAC_SSH" "rm -f $remote_path" 2>/dev/null || true
    echo "$local_path"
}

do_app() {
    local action="${1%%:*}"
    local app="${1#*:}"
    echo "[app] $action: $app" >&2
    local app_q
    app_q=$(shell_escape "$app")
    case "$action" in
        open)
            exec_cmd "open -a ${app_q}"
            ;;
        activate)
            # Pass app name as argv to avoid AppleScript injection
            exec_cmd "osascript -e 'on run argv' -e 'tell application item 1 of argv to activate' -e 'end run' -- ${app_q}"
            ;;
        quit)
            exec_cmd "osascript -e 'on run argv' -e 'tell application item 1 of argv to quit' -e 'end run' -- ${app_q}"
            ;;
        kill)
            exec_cmd "pkill -x ${app_q} || true"
            ;;
        *)
            echo "Unknown app action: $action (use open|activate|quit|kill)" >&2
            exit 1
            ;;
    esac
}

do_file() {
    local direction="${1%%:*}"
    local rest="${1#*:}"
    local src="${rest%%:*}"
    local dst="${rest#*:}"
    echo "[file] $direction: $src → $dst" >&2

    if ! check_ssh; then
        echo '{"error":"SSH unreachable"}' >&2
        exit 1
    fi

    case "$direction" in
        get)  # Mac → local
            scp $SCP_OPTS "$MAC_SSH:$src" "$dst"
            echo "Downloaded: $dst"
            ;;
        put)  # local → Mac
            scp $SCP_OPTS "$src" "$MAC_SSH:$dst"
            echo "Uploaded: $dst"
            ;;
        *)
            echo "Unknown direction: $direction (use get|put)" >&2
            exit 1
            ;;
    esac
}

# --- Main ---
if [ $# -lt 1 ]; then
    echo "Usage: $0 --run|--screenshot|--app|--file [args]" >&2
    exit 1
fi

case "$1" in
    --run)
        [ -z "${2:-}" ] && { echo "Missing command" >&2; exit 1; }
        do_run "$2" "${3:-30}"
        ;;
    --screenshot)
        do_screenshot "${2:-/tmp/mac_screenshot.png}"
        ;;
    --app)
        [ -z "${2:-}" ] && { echo "Missing: open|activate|quit|kill:AppName" >&2; exit 1; }
        do_app "$2"
        ;;
    --file)
        [ -z "${2:-}" ] && { echo "Missing: get|put:src:dst" >&2; exit 1; }
        do_file "$2"
        ;;
    *)
        echo "Unknown option: $1" >&2
        exit 1
        ;;
esac
