# ut99-do

Script to set up and run an Unreal Tournament 99 server on Digital Ocean.

```
Usage: ut99 <command>

Commands:
  create   Create and provision a UT99 server
  destroy  Destroy the UT99 server
  start    Start the UT99 server (power on)
  stop     Stop the UT99 server (power off)
  maps     List available maps, or set map rotation
```

Create `ut99.conf` (see `ut99.conf.example`) and set the droplet name, region and map rotation you want.

Optionally downloads custom content from a Digital Ocean Space if `SPACE_NAME` is set in the config file. The Space uses two subfolders, both optional:

- `maps/` — custom `.unr` map files, installed to `/opt/ut99/Maps/`
- `plugins/` — `.u` plugin files (mutators, gametypes, etc.), installed to `/opt/ut99/System/`

If a folder is absent or empty, that category is silently skipped.

## Dependencies

- `doctl` (with authentication set up — see below)
- An SSH key registered in your DigitalOcean account (`doctl compute ssh-key create`)
- `nc` (netcat)
- `ssh`

### DigitalOcean PAT permissions

Create a custom Personal Access Token at https://cloud.digitalocean.com/account/api/tokens with these scopes:

- **account** — read
- **droplet** — create, read, delete
- **ssh_key** — read
