# Config Cleanup, Map Rotation, and Bot Settings — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Clean up config error handling to use die(), add configurable map rotation auto-applied after create, and hardcode easy bot fill-in during provisioning.

**Architecture:** Three independent changes to the single `ut99` script and `ut99.conf.example`. Config validation uses die() after moving it above the config block. Map rotation is a bash array in config, applied via existing `cmd_maps` after provisioning. Bot settings are two additional sed lines in the provisioning heredoc.

**Tech Stack:** Bash, sed, UT99 INI configuration

---

### Task 1: Move die() and info() above config block, use die() for config errors

**Files:**
- Modify: `ut99:1-21`

**Step 1: Restructure the top of the script**

Replace lines 1-21 with this new ordering that puts die() and info() before config loading, then uses die() for all config validation:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

die() {
    echo "error: $*" >&2
    exit 1
}

info() {
    echo "==> $*"
}

[[ -f "$SCRIPT_DIR/ut99.conf" ]] || die "Config file not found: $SCRIPT_DIR/ut99.conf (see ut99.conf.example)"
source "$SCRIPT_DIR/ut99.conf"
[[ -n "${DROPLET_NAME:-}" ]] || die "DROPLET_NAME not set in ut99.conf"
[[ -n "${REGION:-}" ]]       || die "REGION not set in ut99.conf"
[[ -n "${SPACE_NAME:-}" ]]   || die "SPACE_NAME not set in ut99.conf"

DROPLET_SIZE="s-1vcpu-1gb"
DROPLET_IMAGE="ubuntu-24-04-x64"
```

**Step 2: Verify script still parses**

Run: `bash -n ut99`
Expected: no output (clean parse)

**Step 3: Commit**

```
git add ut99
git commit -m "Use die() for config error handling"
```

---

### Task 2: Add MAP_ROTATION config and auto-apply after create

**Files:**
- Modify: `ut99.conf.example`
- Modify: `ut99` (config validation block, and `cmd_create`)

**Step 1: Add MAP_ROTATION to ut99.conf.example**

Replace the full contents of `ut99.conf.example` with:

```bash
DROPLET_NAME=my-server
REGION=lon1
SPACE_NAME=my-space
MAP_ROTATION=(DM-Deck16][ DM-Phobos][ DM-Morpheus)
```

**Step 2: Add MAP_ROTATION validation to config block**

After the `SPACE_NAME` validation line, add:

```bash
[[ ${#MAP_ROTATION[@]} -gt 0 ]] 2>/dev/null || die "MAP_ROTATION not set in ut99.conf"
```

Note: the `2>/dev/null` handles the case where MAP_ROTATION is completely unset (bash would error on `${#MAP_ROTATION[@]}` with `set -u`).

**Step 3: Auto-apply map rotation after create**

In `cmd_create`, after `check_server_health "$ip"` (line 335) and before the "server ready" info line, add:

```bash
    info "Setting map rotation..."
    DROPLET_IP="$ip"
    cmd_maps "${MAP_ROTATION[@]}"
```

We set `DROPLET_IP` directly since we already have the IP, and `cmd_maps` calls `require_running_droplet` which will set it anyway (but also does an unnecessary API call). Actually — `cmd_maps` calls `require_running_droplet` which sets `DROPLET_ID` and `DROPLET_IP` as globals. We should just let it do its thing. Simpler:

```bash
    info "Setting map rotation..."
    cmd_maps "${MAP_ROTATION[@]}"
```

**Step 4: Verify script still parses**

Run: `bash -n ut99`
Expected: no output (clean parse)

**Step 5: Commit**

```
git add ut99 ut99.conf.example
git commit -m "Add MAP_ROTATION config, auto-apply after create"
```

---

### Task 3: Hardcode MinPlayers=2 and Difficulty=0 in provisioning

**Files:**
- Modify: `ut99` (provisioning heredoc, around line 164)

**Step 1: Add bot configuration sed lines**

After the existing `ServerName` sed line (line 164) and before the systemd service section, add:

```bash
sed -i 's/^MinPlayers=.*/MinPlayers=2/' "$INI"

echo "==> Configuring bot difficulty..."
sed -i 's/^Difficulty=.*/Difficulty=0/' /opt/ut99/System64/User.ini
```

The `MinPlayers=2` goes in `UnrealTournament.ini` (already assigned to `$INI`). The `Difficulty=0` goes in `User.ini` (different file).

**Step 2: Verify script still parses**

Run: `bash -n ut99`
Expected: no output (clean parse)

**Step 3: Commit**

```
git add ut99
git commit -m "Hardcode MinPlayers=2 and easy bot difficulty"
```
