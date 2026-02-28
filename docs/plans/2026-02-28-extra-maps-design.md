# Extra Maps from DO Space - Design

## Goal

Download extra .unr map files from a public DigitalOcean Space into `/opt/ut99/Maps/` during droplet provisioning, so they're available via `ut99 maps`.

## Approach

Add a block to the `provision_server()` heredoc that fetches and installs maps from the Space. No new commands, no changes to existing commands.

## Config

Read from `ut99.conf`:

- `SPACE_NAME` — name of the DO Space
- `REGION` — shared region for droplet and Space

The Space URL is constructed as `https://${SPACE_NAME}.${REGION}.digitaloceanspaces.com`.

## Provisioning Change

After UT99 install completes and before systemd service setup, add:

1. `curl` the Space root URL to get the S3 XML bucket listing
2. Parse `<Key>` values ending in `.unr` (case-insensitive) using `grep` and `sed`
3. Download each file with `curl` into `/opt/ut99/Maps/`
4. Set ownership to `ut99:ut99`

## Error Handling

`set -e` is already active in the provisioning heredoc, so a failed `curl` aborts provisioning immediately (fail fast).

## No Other Changes

Extra maps appear in `/opt/ut99/Maps/`, so `ut99 maps` lists them automatically.
