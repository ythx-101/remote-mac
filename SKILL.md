---
name: remote-mac
description: Control a remote macOS machine from Linux/VPS via SSH
---

# Remote Mac Control

Execute commands, take screenshots, control apps, and transfer files on a remote macOS machine over SSH.

## Setup

Copy the example config and fill in your details:

```bash
cp skills/our/remote-mac/remote-mac.conf.example ~/.remote-mac.conf
# Edit ~/.remote-mac.conf with your SSH host/user
```

Or set environment variables directly:

```bash
export MAC_SSH_HOST="your-mac-ip-or-hostname"
export MAC_SSH_USER="your-username"
export MAC_SSH_PORT="22"         # optional, default 22
export MAC_BRIDGE_URL="http://your-mac-ip:19999/health"  # optional
```

## Usage

### Run a command
```bash
bash skills/our/remote-mac/scripts/mac_exec.sh --run "ls -la ~"
bash skills/our/remote-mac/scripts/mac_exec.sh --run "sw_vers"
bash skills/our/remote-mac/scripts/mac_exec.sh --run "some-long-cmd" 120  # 120s timeout
```

### Screenshot
```bash
bash skills/our/remote-mac/scripts/mac_exec.sh --screenshot
bash skills/our/remote-mac/scripts/mac_exec.sh --screenshot /tmp/screen.png
```

### App control
```bash
bash skills/our/remote-mac/scripts/mac_exec.sh --app "open:Safari"
bash skills/our/remote-mac/scripts/mac_exec.sh --app "activate:Finder"
bash skills/our/remote-mac/scripts/mac_exec.sh --app "quit:Safari"
bash skills/our/remote-mac/scripts/mac_exec.sh --app "kill:AppName"   # force kill (pkill -x)
```

### File transfer
```bash
# Mac → local
bash skills/our/remote-mac/scripts/mac_exec.sh --file "get:~/Desktop/file.txt:/tmp/file.txt"

# local → Mac
bash skills/our/remote-mac/scripts/mac_exec.sh --file "put:/tmp/local.txt:~/Desktop/"
```

### Channel status check
```bash
bash skills/our/remote-mac/scripts/channel_check.sh
# Output: { "ssh": { "available": true, ... }, "ag_bridge": { ... }, "preferred": "ssh" }
```

## OpenClaw Node integration (optional)

If you have an OpenClaw Node agent running on the Mac, you can use the `nodes.run` tool directly from the AI for low-latency commands — no SSH needed:

```
nodes: action=run, node=<your-node-id>, command=["bash", "-c", "your command"]
```

## Notes

- GUI operations (screenshots, app control) require an active desktop session — **won't work if the screen is locked**
- To prevent sleep: `bash skills/our/remote-mac/scripts/mac_exec.sh --run "caffeinate -d &"`
- SSH multiplexing is used (ControlMaster) — first connection may be slow, subsequent ones are fast
- Timeout fallback chain: `gtimeout` → `timeout` → no timeout (macOS compatibility)
