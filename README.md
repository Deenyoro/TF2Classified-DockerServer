# TF2 Classified Docker Server

Dockerized TF2 Classified dedicated server. Edit `.env`, run `docker compose up -d`, done.

- IP hidden by default via Steam Datagram Relay
- Auto-updates TF2 base and TF2 Classified while running
- MetaMod:Source, SourceMod, and SMJansson pre-installed
- Multi-server support with shared game files (~22GB installs once)
- Configurable Docker logging per server
- FastDL auto-compression on startup

## Quick Start

```bash
./setup.sh                    # creates dirs, generates .env with random RCON pass
nano .env                     # tweak to your liking
docker compose up -d          # build + run
docker compose logs -f        # watch it (first boot downloads ~22GB)
```

Or: `make setup && make start && make logs`

## How Players Connect

With Steam Networking on (default), the server shows up in the TF2C browser. Players find it by name and join. The downside is they can't favorite it since the relay address is ephemeral.

Without Steam Networking, players connect by your public IP directly. You'd need to port-forward 27015/UDP and your IP is exposed.

| | IP Hidden | Favoritable | Port Forward |
|-|-----------|-------------|-------------|
| Steam Networking (default) | yes | no | no |
| Direct | no | yes | yes |

## Configuration

Everything is in `.env`. The important ones:

| Variable | Default | What it does |
|----------|---------|-------------|
| `SERVER_NAME` | `My TF2 Classified Server` | Browser listing name |
| `SERVER_PASSWORD` | *(empty)* | Empty = public |
| `RCON_PASSWORD` | `changeme` | Remote admin password. **Change this.** |
| `START_MAP` | `ctf_2fort` | Map on boot |
| `MAX_PLAYERS` | `24` | Up to 32 |
| `SERVER_PORT` | `27015` | Game port |
| `TICKRATE` | `66` | Server tickrate |
| `STEAM_NETWORKING` | `true` | IP hiding via Valve relay |
| `UPDATE_ON_START` | `true` | Run SteamCMD update on each start |
| `AUTO_UPDATE` | `true` | Poll for updates while running, restart when found |
| `AUTO_UPDATE_INTERVAL` | `300` | Seconds between update checks |
| `SERVER_CFG_MODE` | `auto` | `auto` = rebuild server.cfg from .env every boot. `custom` = you manage it |
| `SM_ADMIN_STEAMID` | *(empty)* | Your Steam ID for SM admin |
| `SV_TAGS` | *(empty)* | Server browser tags |
| `LOG_MAX_SIZE` | `10m` | Max Docker log file size per server |
| `LOG_MAX_FILE` | `3` | Number of rotated log files to keep |

Mod URLs (`MMS_URL`, `SM_URL`, `SMJANSSON_URL`) default to known-good 64-bit Linux builds. Set any to `skip` to disable. Set `INSTALL_MODS=false` to skip all of them.

## Auto-Updates

`UPDATE_ON_START=true` runs SteamCMD before each launch. `AUTO_UPDATE=true` runs a background loop that polls Steam every `AUTO_UPDATE_INTERVAL` seconds. When it sees a new build ID, it kills srcds. Docker's restart policy brings the container back up and the update gets applied on the way in.

Disable background polling with `AUTO_UPDATE=false` — the server still updates on restart.

## Custom Map Downloads (FastDL)

Source normally trickle-feeds map files through the game connection. FastDL tells clients to grab them over HTTP instead.

Maps in `data/maps/` are automatically compressed to `data/fastdl/tf2classified/maps/` on container startup. You can also run it manually:

```bash
make compress-maps
```

Host the compressed files somewhere (Cloudflare R2 is free and works well, or use the included nginx with `docker compose --profile fastdl up -d`), then set `FASTDL_URL` in `.env` and restart.

Your web root needs to mirror the game directory layout:

```
data/fastdl/tf2classified/maps/custom_map.bsp.bz2
```

Upload both `.bsp` and `.bsp.bz2` — clients try compressed first and fall back to raw.

## Custom Content

**Configs:** Drop `.cfg` files in `data/cfg/`. In auto mode, `server.cfg` gets rebuilt from `.env` every boot — put your overrides in `data/cfg/server_custom.cfg`. Set `SERVER_CFG_MODE=custom` if you want to manage `server.cfg` yourself.

**Maps:** `.bsp` files go in `data/maps/`.

**MOTD:** Put `motd.txt` (HTML) and optionally `motd_default.txt` (plain text fallback) in `data/cfg/`.

**SourceMod plugins:** `.smx` files go in `data/addons/sourcemod/plugins/`.

**SM admin:** Set `SM_ADMIN_STEAMID=STEAM_0:1:12345678` in `.env` ([steamid.io](https://steamid.io)).

## Running Multiple Servers

All servers share game files (~22GB downloads once). Each server has its own config, logs, and port.

```bash
make add-server N=2    # creates dirs + .env.server2
nano .env.server2      # change name, port, RCON, etc.
make start-server N=2
make logs-server N=2
```

### What's shared vs per-server

| Content | Primary Server | Server N | Can Share? |
|---------|---------------|----------|------------|
| Game files (TF2 + TF2C) | `tf2-data` volume | Same volume | Always shared |
| Configs | `data/cfg/` | `servers/N/cfg/` | Edit docker-compose.yml |
| Addons | `data/addons/` | `servers/N/addons/` | Edit docker-compose.yml |
| Maps | `data/maps/` | `servers/N/maps/` | Edit docker-compose.yml |
| Logs | `data/logs/` | `servers/N/logs/` | Never shared |
| Demos | `data/demos/` | `servers/N/demos/` | Never shared |

To share maps/addons across all servers, edit `docker-compose.yml` and change `./servers/N/maps` to `./data/maps` (same for addons).

Secondary servers set `UPDATE_GAME_FILES=false` since the primary handles updates. Each server gets a unique `SERVER_PORT` (27016, 27017, etc).

### Per-server logging

Each server reads `LOG_MAX_SIZE` and `LOG_MAX_FILE` from its own `.env.serverN` file, so you can configure different log retention per server.

## Server Console

The srcds process runs inside a tmux session, giving you full interactive console access.

### Attach to the console

```bash
make console                # primary server
make console-server N=2     # server N
```

Or directly:

```bash
docker compose exec tf2classified tmux attach -t srcds
docker compose exec tf2classified-2 tmux attach -t srcds   # server 2
```

Once attached you're in the live srcds console — type commands like `status`, `changelevel`, `sm plugins list`, etc. exactly as you would on a local dedicated server.

**Detach without stopping the server:** press `Ctrl+B`, then `D`.

### Send commands without attaching

Fire-and-forget commands from outside the console:

```bash
docker compose exec tf2classified tmux send-keys -t srcds "status" Enter
docker compose exec tf2classified tmux send-keys -t srcds "changelevel pl_upward" Enter
docker compose exec tf2classified tmux send-keys -t srcds "sm plugins list" Enter
```

This is useful for scripts, cron jobs, or quick one-off commands.

### RCON

RCON works on localhost inside the container. From the host:

```bash
# Install rcon-cli or any RCON client
rcon -a 127.0.0.1:27015 -p yourpassword status
```

RCON also works when Steam Networking (SDR) is enabled because srcds still listens on the local port.

### Other management commands

```bash
docker compose logs -f                                    # tail logs
docker compose exec tf2classified /opt/scripts/update.sh  # manual update
docker compose restart                                    # restart
docker compose down                                       # stop
docker compose build --no-cache && docker compose up -d   # full rebuild
```

## What Gets Installed

The image is just Debian + SteamCMD + runtime libs (~500MB). Game files go into Docker volumes on first boot:

- **AppID 232250** — TF2 Dedicated Server (~15GB)
- **AppID 3557020** — TF2 Classified (~7GB)
- **MetaMod:Source 2.0** build 1384 (TF2C needs >= 1380)
- **SourceMod 1.13** build 7293 (includes TF2C gamedata)
- **SMJansson 2.6.1** 64-bit (JSON extension for plugins)

These install once on first boot. Delete the `classified-data` volume to force a reinstall.

## Server Verification

Once your server is running, you can ask the TF2C team for manual verification. Verified servers can use `SV_TAGS`:

- `type_customrules` — custom gamemodes, civilian, bhop, etc.
- `type_customweapons` — rebalance packs, throwback weapons

## Troubleshooting

**Server not in browser:** Steam Networking can take a couple minutes to register. Without it, check that 27015/UDP is forwarded.

**SourceMod not loading:** Check logs for download errors. Make sure `metamod.vdf` exists:
```bash
docker compose exec tf2classified cat /data/classified/tf2classified/addons/metamod.vdf
```

**Container exits on first run:** It's downloading ~22GB. Watch with `docker compose logs -f`. If SteamCMD keeps failing, try `VALIDATE_INSTALL=1`.

**Disk space:** You need at least 25GB free for the initial download.

## Links

- TF2C Wiki server guide: https://wiki.tf2classic.com/wiki/Dedicated_Linux_server
- TF2C on Steam: https://store.steampowered.com/app/3545060
- SourceMod: https://www.sourcemod.net
- MetaMod:Source: https://www.metamodsource.net
- SMJansson: https://github.com/srcdslab/sm-ext-SMJansson
