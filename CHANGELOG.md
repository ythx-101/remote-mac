# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [1.1.0] - 2026-03-03

### Changed
- Extracted shared logic into `scripts/common.sh` — config loading, ControlPath, `shell_escape()`, `json_escape()`, `now_ms()`; both scripts now `source` it
- Fixed config loading priority: environment variables now correctly override config file values (was reversed in v1.0.0); priority is now `env > ~/.remote-mac.conf > defaults`

### Added
- `--help` / `-h` flag in `mac_exec.sh` prints usage and exits
- Timeout validation in `do_run`: non-numeric values now fail with a clear error

### Fixed
- `do_screenshot` remote path now includes `$RANDOM` to avoid rare PID collisions
- `do_file` scp paths are now quoted to handle spaces in filenames

---

## [1.0.0] - 2026-03-03

First public release.

### Features
- `mac_exec.sh` — run commands, take screenshots, control apps, transfer files on a remote Mac over SSH
- `channel_check.sh` — check SSH and Antigravity bridge availability, output structured JSON
- Config via `~/.remote-mac.conf` or environment variables — no hardcoded values
- SSH multiplexing (ControlMaster) for fast repeated invocations
- Timeout fallback chain: `gtimeout` → `timeout` → bare (macOS + Linux compatible)

### Security
- `StrictHostKeyChecking=accept-new` (replaces `no`) — non-interactive but MITM-safe
- Portable SSH `ControlPath`: `XDG_RUNTIME_DIR` → `TMPDIR` → `~/.cache/remote-mac`
- `shell_escape()` function for app names — prevents shell and AppleScript injection
- AppleScript uses `argv` passing instead of string interpolation
- `json_escape()` in `channel_check.sh` — all dynamic values encoded via `python3 json.dumps`
- `curl -sSf` for bridge health check — HTTP 4xx/5xx correctly mark bridge unavailable
- Separate `SSH_OPTS` / `SCP_OPTS` — eliminates `-p`/`-P` option conflict
