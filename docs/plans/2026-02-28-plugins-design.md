# Plugin Support & Space Folder Structure

## Summary

Add plugin installation support and reorganize the DigitalOcean Space to use subfolders for maps and plugins.

## Space Structure

```
Space root/
  maps/        -- .unr map files (moved from root)
  plugins/     -- .u plugin files (new)
```

Either folder can be absent. If absent, that category is silently skipped.

## Server Installation Paths

| Space folder | Server destination     |
|--------------|------------------------|
| `maps/`      | `/opt/ut99/Maps/`      |
| `plugins/`   | `/opt/ut99/System/`    |

## Implementation

A generic `download_from_space` function replaces the current inline map download logic. It takes a Space URL, a subfolder name, and a server destination directory. It:

1. Lists the subfolder contents using S3 `?prefix=folder/`
2. If no keys are found, skips silently
3. Downloads each file to the destination directory
4. Sets ownership to `ut99:ut99`

Called twice during provisioning:
- `download_from_space "$space_url" "maps" "/opt/ut99/Maps/"`
- `download_from_space "$space_url" "plugins" "/opt/ut99/System/"`

## What Doesn't Change

- `ut99.conf` schema (no new config variables)
- `set-maps.sh` and map rotation logic
- All other commands (destroy, start, stop, maps)
- Plugins require no ini configuration; dropping files into System/ is sufficient
