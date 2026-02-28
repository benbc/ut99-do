# Config cleanup, map rotation, and bot settings

## Changes

### 1. Use die() for config error handling

Move `die()` and `info()` above the config-loading block (lines 5-9) so they're available. Replace the inline `{ echo "error: ..."; exit 1; }` patterns with `die()`.

### 2. Add initial map rotation to config

Add `MAP_ROTATION` as a bash array in `ut99.conf` / `ut99.conf.example`:

```bash
MAP_ROTATION=(DM-Deck16][ DM-Phobos][ DM-Morpheus)
```

Validate at startup that it's set and non-empty (using `die()`).

After `cmd_create` finishes provisioning and passes the health check, automatically apply the configured rotation by calling `cmd_maps "${MAP_ROTATION[@]}"`.

### 3. Hardcode MinPlayers=2 and Difficulty=0

In the provisioning heredoc, add sed lines to configure:

- `MinPlayers=2` in `UnrealTournament.ini` (ensures one bot joins when only one human is connected)
- `Difficulty=0` in `User.ini` (novice/easiest bot difficulty)

Both files are in `/opt/ut99/System64/`.
