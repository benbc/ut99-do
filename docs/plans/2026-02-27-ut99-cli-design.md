# ut99 CLI Tool Design

Single Bash script (`ut99`) to manage a UT99 dedicated server on Digital Ocean.

## Prerequisites

- `doctl` installed and authenticated
- `ssh` available
- SSH key added to DO account

The script checks for these at startup and fails with a clear message if missing.

## Droplet Configuration

- Name: `ut99` (fixed, used for lookup by all commands)
- Size: smallest available
- Region: LON1
- Image: Ubuntu 24.04 LTS

## Operations

All operations are idempotent unless otherwise noted.

### `ut99 create`

1. If droplet `ut99` already exists and is provisioned, print its IP and exit 0
2. Create droplet via `doctl`
3. Wait for active + SSH ready
4. SSH in, run OldUnreal `install-ut99.sh` (`--ui-mode none`, destination `/opt/ut99`)
5. Create a `ut99` system user to run the server (not root)
6. Write tuned `UnrealTournament.ini` (see Server Configuration below)
7. Install systemd service (see Systemd Service below)
8. Configure UFW firewall (see Firewall below)
9. Enable and start the service
10. Verify server responds on UDP query port 7778
11. Print IP address

### `ut99 destroy`

1. Find droplet `ut99`. If not found, exit 0 (nothing to destroy)
2. Destroy it

### `ut99 start`

1. Find droplet `ut99`. If not found, fail (can't start what doesn't exist)
2. If already running, print IP and exit 0
3. Power on via `doctl`
4. Wait for droplet to be active
5. Verify server responds on UDP query port 7778
6. Print IP

No SSH needed. The systemd service is `WantedBy=multi-user.target` so it starts on boot.

### `ut99 stop`

1. Find droplet `ut99`. If not found, fail
2. If already off, say so and exit 0
3. Shut down via `doctl compute droplet-action shutdown` (ACPI shutdown signal)
4. Wait for droplet to be off

No SSH needed. ACPI shutdown triggers systemd's normal stop sequence, which sends SIGINT to ucc-bin for clean shutdown.

## Server Configuration

Key `UnrealTournament.ini` settings:

| Setting | Value | Reason |
|---------|-------|--------|
| `NetServerMaxTickRate` | 35 | Good balance for standard DM/CTF |
| `MaxClientRate` | 15000 | Reasonable bandwidth per client |
| `UseCompression` | True | Compress downloads to clients |
| `CacheSizeMegs` | 64 | Memory is cheap on our droplet |

Plus sensible defaults for: server name, game mode (DM), standard map rotation.

## Systemd Service

`/etc/systemd/system/ut99.service`:

- `User=ut99` (dedicated system user, not root)
- `ExecStart` launches `ucc-bin server` with appropriate args
- `KillSignal=SIGINT` for clean shutdown
- `TimeoutStopSec=30`
- `WantedBy=multi-user.target` (auto-start on boot)

## Firewall (UFW)

- Allow 7777-7779/udp (game, query, uplink)
- Allow 22/tcp (SSH management)
- Default deny inbound

No web admin exposed (unnecessary attack surface).

## Health Check

After `create` and `start`, probe UDP port 7778 (UT query protocol) to confirm the server is responding. Confirms end-to-end: droplet up, service running, firewall open.

## Out of Scope (v1)

- Custom maps / map rotation config
- Game mode selection
- Multiple servers
- Web admin interface
