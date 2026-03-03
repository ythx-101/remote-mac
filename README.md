# remote-mac

> Control a remote macOS machine from Linux/VPS via SSH — screenshots, commands, app control, file transfer.

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Shell](https://img.shields.io/badge/shell-bash-green.svg)](scripts/mac_exec.sh)
[![Platform](https://img.shields.io/badge/platform-Linux%20%2F%20macOS-lightgrey.svg)]()

---

## What it does

Two shell scripts. No dependencies beyond `ssh`, `scp`, `curl`, and `python3` (standard on any modern system).

| Script | Purpose |
|--------|---------|
| `mac_exec.sh` | Run commands, take screenshots, control apps, transfer files |
| `channel_check.sh` | Check SSH + bridge availability, output JSON |

Works great paired with [OpenClaw](https://github.com/openclaw/openclaw) as a remote Mac control layer for AI agents.

---

## Quick start

```bash
# 1. Clone
git clone https://github.com/ythx-101/remote-mac.git
cd remote-mac

# 2. Configure (copy example, fill in your SSH host/user)
cp remote-mac.conf.example ~/.remote-mac.conf
$EDITOR ~/.remote-mac.conf

# 3. Run
bash scripts/mac_exec.sh --run "sw_vers"
```

Or configure via environment variables (no config file needed):

```bash
export MAC_SSH_HOST="your-mac-ip-or-hostname"
export MAC_SSH_USER="your-username"
export MAC_SSH_PORT="22"  # default: 22
```

---

## Usage

### Run a remote command

```bash
bash scripts/mac_exec.sh --run "ls -la ~"
bash scripts/mac_exec.sh --run "brew list"
bash scripts/mac_exec.sh --run "some-long-script.sh" 120   # custom timeout (seconds)
```

### Screenshot

```bash
bash scripts/mac_exec.sh --screenshot                      # saves to /tmp/mac_screenshot.png
bash scripts/mac_exec.sh --screenshot /tmp/myscreen.png
```

> Requires an active desktop session. Won't work if the screen is locked.

### App control

```bash
bash scripts/mac_exec.sh --app "open:Safari"
bash scripts/mac_exec.sh --app "activate:Finder"
bash scripts/mac_exec.sh --app "quit:Safari"
bash scripts/mac_exec.sh --app "kill:AppName"    # force kill via pkill -x
```

### File transfer

```bash
# Mac → local
bash scripts/mac_exec.sh --file "get:~/Desktop/report.pdf:/tmp/report.pdf"

# local → Mac
bash scripts/mac_exec.sh --file "put:/tmp/script.sh:~/Desktop/"
```

### Channel status (JSON)

```bash
bash scripts/channel_check.sh
```

```json
{
  "timestamp": "2026-03-03T07:42:00Z",
  "ssh": { "available": true, "latency_ms": 42, "target": "user@mac.local:22" },
  "ag_bridge": { "available": false, "latency_ms": 0, "status": "" },
  "preferred": "ssh"
}
```

---

## Configuration

All config via `~/.remote-mac.conf` or environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `MAC_SSH_HOST` | `mac.local` | SSH hostname or IP (Tailscale, LAN, etc.) |
| `MAC_SSH_USER` | current user | SSH username on the Mac |
| `MAC_SSH_PORT` | `22` | SSH port |
| `MAC_BRIDGE_URL` | _(empty)_ | Optional: Antigravity bridge health URL |
| `REMOTE_MAC_CONF` | `~/.remote-mac.conf` | Custom config file path |
| `REMOTE_MAC_CONTROL_DIR` | auto | Override SSH ControlPath directory |

See [`remote-mac.conf.example`](remote-mac.conf.example) for a commented template.

---

## Security

- **No hardcoded secrets** — all config via env vars or `~/.remote-mac.conf` (never committed)
- **`StrictHostKeyChecking=accept-new`** — non-interactive but won't silently accept changed host keys
- **Shell injection protection** — app names are single-quoted via `shell_escape()`; AppleScript uses `argv` passing
- **JSON injection protection** — all dynamic values in `channel_check.sh` output are encoded via `python3 json.dumps`
- **Portable ControlPath** — uses `XDG_RUNTIME_DIR` → `TMPDIR` → `~/.cache/remote-mac` (works on both Linux and macOS)

---

## Tips

**Keep Mac awake:**
```bash
bash scripts/mac_exec.sh --run "caffeinate -d &"
```

**SSH multiplexing** is enabled by default (`ControlMaster=auto`, `ControlPersist=10m`). First connection is slow; subsequent calls are near-instant.

**Tailscale:** Works great with Tailscale — set `MAC_SSH_HOST` to your Mac's Tailscale IP for reliable remote access from anywhere.

---

## License

MIT
