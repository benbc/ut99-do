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

Optionally downloads custom maps from a Digtal Ocean space if the name is provided in the config file.

## Dependencies

- `doctl` (with authentication set up)
- `nc` (netcat)
- `ssh`
