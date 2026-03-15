# Web Admin Design

## Overview

Enable the UT99 built-in HTTP web admin, secure it behind a Caddy TLS reverse proxy, and
remove CLI-based map management in favour of the web interface. Players and admins manage
maps, game settings, and players through the browser; the wrapper script handles
infrastructure only.

Final architecture:

```
Browser (HTTPS) → Caddy :443 → UT99 Web Admin :5080 (localhost only)
```

---

## Config (`ut99.conf` / `ut99.conf.example`)

**Add three required variables:**

```bash
ADMIN_DOMAIN=ut-admin.yourdomain.com   # DNS subdomain pointing at server IP
WEBADMIN_PASSWORD=...                   # web admin login password
INGAME_ADMIN_PASSWORD=...              # separate in-game adminlogin password
```

**Remove:** `MAP_ROTATION`

`ut99` validates all three new variables at startup (fail-fast, same pattern as existing
checks). `MAP_ROTATION` validation is removed.

DNS is managed manually. The `ADMIN_DOMAIN` record is updated by hand when the server IP
changes. Automation (e.g. delegating to DigitalOcean DNS) is out of scope.

---

## Provisioning (`server/provision.sh`)

Signature extended to four positional args:

```
provision.sh <space_url> <admin_domain> <webadmin_password> <ingame_admin_password>
```

`space_url` remains optional (empty string if `SPACE_NAME` is unset), consistent with
current behaviour.

### INI changes

Applied via `sed -i`, consistent with existing pattern. Added settings:

```ini
[UWeb.WebServer]
bEnabled=True
ListenPort=5080

[UTServerAdmin.UTServerAdmin]
AdminUsername=admin
AdminPassword=<WEBADMIN_PASSWORD>

[Engine.GameInfo]
AdminPassword=<INGAME_ADMIN_PASSWORD>
LoginDelaySeconds=1.000000
MaxLoginAttempts=50
```

After writing: `chmod 600 "$INI"` — passwords are stored in plaintext in the INI file.

### Caddy

Install Caddy using the official Debian/Ubuntu procedure (apt repository). Write
`/etc/caddy/Caddyfile`:

```caddyfile
<ADMIN_DOMAIN> {
    redir / /ServerAdmin/ permanent
    reverse_proxy localhost:5080
}
```

The `redir` directive intercepts bare `/` requests before they reach UT99, preventing UT99
from issuing a redirect that resolves to its internal LAN IP (a known gotcha with the UT99
web server). Enable and start Caddy as a systemd service.

### Firewall

Add `ufw allow 443/tcp` in `provision.sh` (alongside existing rules) so Caddy can serve
HTTPS. No other changes. `ufw default deny incoming` already blocks port 5080 from
external access. Caddy reaches 5080 via loopback, which UFW permits. Raw `iptables` rules
are not used (mixing UFW and raw iptables is fragile).

### Removed

The `cmd_maps "${MAP_ROTATION[@]}"` call after the reboot is removed. The server starts
with UT99's default map rotation; admins configure it from the web admin.

---

## `server/set-maps.sh`

Deleted. Map rotation is managed entirely through the web admin.

---

## `ut99` Script

### Removed

- `cmd_maps` function
- `maps` subcommand (from `main` dispatch and `usage`)
- `MAP_ROTATION` config validation

### Added — `cmd_info`

Prints the server IP and the full web admin URL. Calls `require_running_droplet` to
obtain the IP (sets global `DROPLET_IP`). When called from `cmd_create` or `cmd_start`,
the droplet is already confirmed running so the check is a fast no-op.

Example output:

```
==> Server info
IP:        1.2.3.4
Web admin: https://ut-admin.yourdomain.com/ServerAdmin/
```

Registered as `ut99 info` in `usage` and `main`.

### Modified — `cmd_create`

Removes the `cmd_maps "${MAP_ROTATION[@]}"` call. Replaces the final status message
(`info "UT99 server ready..."` + `echo "$ip"`) with a call to `cmd_info`.

### Modified — `cmd_start`

Replaces the final status message with a call to `cmd_info`.

### Modified — `provision_server`

Passes `ADMIN_DOMAIN`, `WEBADMIN_PASSWORD`, and `INGAME_ADMIN_PASSWORD` as additional
positional args to `provision.sh`.

### Unchanged

`cmd_map_add` — maps are copied directly to `/opt/ut99/Maps/`, which is where the web
admin looks for available maps. No changes needed.

---

## Security Notes

- Caddy handles TLS automatically via Let's Encrypt; port 443 must be open in UFW.
- Port 5080 is not opened in UFW; only loopback access is possible.
- Passwords are stored in plaintext in `UnrealTournament.ini`; `chmod 600` is applied
  during provisioning.
- Web admin and in-game admin passwords must be distinct values.
- Brute-force protection is active via `LoginDelaySeconds` and `MaxLoginAttempts`.
