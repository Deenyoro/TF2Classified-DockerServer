# TF2 Classified Docker Server

Dockerized TF2 Classified dedicated server. Edit `.env`, run `docker compose up -d`, done.

- IP hidden by default via Steam Datagram Relay
- Auto-updates TF2 base and TF2 Classified while running
- MetaMod:Source, SourceMod, and SMJansson pre-installed
- 9 optional addons (VSH, War3Source, RTD, MapChooser Extended, and more)
- Multi-server support with shared game files (~22GB installs once)
- Per-server addon configs — run a VSH server, a War3Source server, and a vanilla server side by side
- FastDL auto-compression on startup
- Full interactive server console via tmux

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
| `SERVER_PORT` | `27015` | Game port (UDP) |
| `TICKRATE` | `66` | Server tickrate |
| `STEAM_NETWORKING` | `true` | IP hiding via Valve relay |
| `UPDATE_ON_START` | `true` | Run SteamCMD update on each start |
| `AUTO_UPDATE` | `true` | Poll for updates while running |
| `AUTO_UPDATE_MODE` | `immediate` | `immediate`, `graceful`, or `announce` — see [Auto-Updates](#auto-updates) |
| `UPDATE_GRACE_PERIOD` | `60` | Seconds to wait in graceful mode |
| `AUTO_UPDATE_INTERVAL` | `300` | Seconds between update checks |
| `SERVER_CFG_MODE` | `auto` | `auto` = rebuild server.cfg from .env every boot. `custom` = you manage it |
| `SM_ADMIN_STEAMID` | *(empty)* | Your Steam ID for SM admin |
| `SV_TAGS` | *(empty)* | Server browser tags |
| `LOG_MAX_SIZE` | `10m` | Max Docker log file size per server |
| `LOG_MAX_FILE` | `3` | Number of rotated log files to keep |
| `EXTRA_ARGS` | *(empty)* | Extra srcds command-line arguments |
| `FASTDL_PORT` | `8080` | Host port for self-hosted FastDL nginx |
| `TMUX_REMAIN_ON_EXIT` | `false` | Keep tmux session after crash (for debugging) |
| `ADDON_*` | `false` | Optional addons — see [Optional Addons](#optional-addons) |

Mod URLs (`MMS_URL`, `SM_URL`) default to known-good 64-bit Linux builds. Set either to `skip` to disable installing that component. Set `INSTALL_MODS=false` to skip all mod installation.

## Auto-Updates

`UPDATE_ON_START=true` runs SteamCMD before each launch. `AUTO_UPDATE=true` runs a background loop that polls Steam every `AUTO_UPDATE_INTERVAL` seconds.

### Update Modes

Control what happens when an update is detected with `AUTO_UPDATE_MODE`:

| Mode | Behavior |
|------|----------|
| `immediate` | Stop server right away (default) |
| `graceful` | Warn players in chat, wait `UPDATE_GRACE_PERIOD` seconds, then restart |
| `announce` | Warn players but wait for manual restart |

**Graceful mode** sends countdown warnings to players at 5min, 2min, 1min, 30s, 10s, and final countdown. To extend the grace period during countdown:

```bash
docker compose exec tf2classified touch /tmp/extend_update_grace
```

Each touch adds another `UPDATE_GRACE_PERIOD` seconds.

**Announce mode** notifies players but doesn't auto-restart. Useful if you want to control exactly when restarts happen.

Disable background polling entirely with `AUTO_UPDATE=false` — the server still updates on container restart if `UPDATE_ON_START=true`.

## Custom Content

All custom content goes in bind-mounted directories that persist across container rebuilds.

### Configs

Drop `.cfg` files in `data/cfg/`. In auto mode, `server.cfg` gets rebuilt from `.env` every boot — put your overrides in `data/cfg/server_custom.cfg`. Set `SERVER_CFG_MODE=custom` if you want full control over `server.cfg`.

### Maps

`.bsp` files go in `data/maps/`. They're automatically symlinked into the game directory on startup.

### MOTD

Put `motd.txt` (HTML) and optionally `motd_default.txt` (plain text fallback) in `data/cfg/`:

```bash
echo '<html><body><h1>Welcome!</h1></body></html>' > data/cfg/motd.txt
```

### SourceMod Configs

Override SourceMod settings by placing config files in `data/cfg/sourcemod/`:

```bash
mkdir -p data/cfg/sourcemod
nano data/cfg/sourcemod/sourcemod.cfg
```

These symlink into the game directory on startup, so they persist across rebuilds. You don't need to switch to manual config mode.

Common files to override:
- `sourcemod.cfg` — main SourceMod settings
- `basevotes.cfg` — vote settings
- `funcommands.cfg` — fun command settings

### Addon Configs

Override addon config files (Advertisements, MCE, RTD, VSH, etc.) by placing them in `data/addons/sourcemod/configs/`:

```bash
mkdir -p data/addons/sourcemod/configs
nano data/addons/sourcemod/configs/advertisements.txt
```

Subdirectories work too (e.g. `data/addons/sourcemod/configs/mapchooser_extended/`). These symlink over the addon defaults on startup, so your changes persist across rebuilds and addon reinstalls.

### SourceMod Plugins

`.smx` files go in `data/addons/sourcemod/plugins/`:

```bash
cp myplugin.smx data/addons/sourcemod/plugins/
```

They get loaded on next server start or map change.

### SM Admin

Set `SM_ADMIN_STEAMID=STEAM_0:1:12345678` in `.env` ([steamid.io](https://steamid.io)). Multiple admins: comma-separated.

```
SM_ADMIN_STEAMID=STEAM_0:1:12345678,STEAM_0:0:87654321
```

## Custom Map Downloads (FastDL)

Source normally trickle-feeds map files through the game connection. FastDL tells clients to grab them over HTTP instead — much faster.

Maps in `data/maps/` are automatically compressed to `data/fastdl/tf2classified/maps/` on container startup. You can also run it manually:

```bash
make compress-maps
```

### Hosting options

**Self-hosted (included nginx):**

```bash
docker compose --profile fastdl up -d
# Then set in .env:
FASTDL_URL=http://your-ip:8080/tf2classified
```

**Cloudflare R2 (free 10GB, global CDN):**

```bash
# Configure R2 credentials in .env, then:
make upload-maps
# Set FASTDL_URL to your R2 public bucket URL
```

**Any HTTP server** (S3, Backblaze B2, your own VPS, etc.) — just mirror the game directory layout:

```
<FASTDL_URL>/maps/custom_map.bsp.bz2
<FASTDL_URL>/maps/custom_map.bsp
```

Clients try compressed (`.bsp.bz2`) first and fall back to raw (`.bsp`).

## Optional Addons

All addons are **disabled by default** and must be explicitly enabled in `.env`. Enabling an addon will never break an existing server — they only activate when you opt in. Updating your container image will not enable any addons you haven't turned on.

Set any of these to `true` in `.env` to enable:

| Variable | What it does |
|----------|-------------|
| `ADDON_MAPCHOOSER_EXTENDED=true` | End-of-map voting with nominations and rock-the-vote. Replaces stock mapchooser. |
| `ADDON_NATIVEVOTES=true` | Native TF2 vote UI instead of SourceMod's generic menu. Works standalone or with MCE. |
| `ADDON_ADVERTISEMENTS=true` | Rotating server messages in chat. Configure in `data/addons/sourcemod/configs/advertisements.txt`. |
| `ADDON_RTD=true` | Roll The Dice — `!rtd` gives random temporary effects. Ships a TF2C-compatible build. |
| `ADDON_TF2ATTRIBUTES=true` | Custom weapon attributes framework. Note: limited on TF2C (see [TF2C compatibility](#tf2-classified-compatibility)). |
| `ADDON_VSH=true` | Versus Saxton Hale — boss vs. mercenaries arena mode. Needs `vsh_` prefixed maps in `data/maps/`. |
| `ADDON_WAR3SOURCE=true` | Warcraft 3: Source RPG mod — races, leveling, skills, and shops. Compiled automatically on first boot (~80s). |
| `ADDON_ROUNDTIME=true` | Control round time, setup time, capture time bonuses. Admin commands `sm_addtime` / `sm_settime`. |
| `ADDON_MAPCONFIG=true` | Execute different cfg files per map, prefix, or gametype. Edit `cfg/mapconfig/` to configure. |

### Addon dependencies

Dependencies are installed and cleaned up automatically:

- **VSH** installs: TF2Items extension, TF2 Tools extension (patched for TF2C)
- **War3Source** installs: TF2 Tools extension (patched for TF2C)
- **tf2attributes** installs: TF2 Tools extension (patched for TF2C)
- **Map Config** installs: TF2 Tools extension (patched for TF2C)

When you disable an addon, shared dependencies are only removed once **all** addons that need them are disabled.

### Mix and match across servers

Each server in a multi-server setup gets its own `.env` file with independent addon settings:

```bash
# .env — vanilla server
ADDON_VSH=false
ADDON_WAR3SOURCE=false

# .env.server2 — VSH server
ADDON_VSH=true
SERVER_PORT=27016

# .env.server3 — War3Source server
ADDON_WAR3SOURCE=true
SERVER_PORT=27017

# .env.server4 — RTD + MapChooser
ADDON_RTD=true
ADDON_MAPCHOOSER_EXTENDED=true
SERVER_PORT=27018
```

All servers share the same ~22GB game files.

### TF2 Classified compatibility

TF2 Classified is not stock TF2. Several SourceMod extensions assume the game directory is `tf` and fail on TF2C's `tf2classified` directory. This project handles the differences:

- **Patched TF2 Tools extension** — binary-patched to bypass the hardcoded game directory check
- **TF2C gamedata files** — symbol-based signatures (`linux64` keys) and vtable offsets for TF2C's 64-bit server binary
- **Boot-time validation** — verifies that critical symbols still exist in the TF2C binary after game updates
- **Auto-repair** — gamedata patches and extension integrity are re-verified on every container restart, surviving SourceMod's auto-updater
- **War3Source compilation fixes** — SteamTools stubs (no 64-bit build exists), include path ordering for SM 1.10 compiler compatibility
- **tf2attributes limitation** — TF2C does not have TF2's item economy system (`CEconItemSchema`, `CAttributeList`). The tf2attributes plugin will install but cannot function until TF2C adds economy support. War3Source and VSH work fine without it.

## Running Multiple Servers

All servers share game files (~22GB downloads once). Each server has its own config, addons, logs, and port.

```bash
make add-server N=2    # creates dirs + .env.server2
nano .env.server2      # change name, port, RCON, addons, etc.
make start-server N=2
make stop-server N=2
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

The image is Debian + SteamCMD + runtime libs (~500MB). Game files go into Docker volumes on first boot:

- **AppID 232250** — TF2 Dedicated Server (~15GB)
- **AppID 3557020** — TF2 Classified (~7GB)
- **MetaMod:Source 2.0** build 1384 (TF2C needs >= 1380)
- **SourceMod 1.13** build 7293 (includes TF2C gamedata)
- **SMJansson** 64-bit (JSON extension for plugins — [64-bit build by bottiger](https://forums.alliedmods.net/showthread.php?t=184604&page=8), upstream [srcdslab/sm-ext-SMJansson](https://github.com/srcdslab/sm-ext-SMJansson) only ships 32-bit)

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

**Addon not loading:** Check the SourceMod error logs:
```bash
docker compose exec tf2classified cat /data/classified/tf2classified/addons/sourcemod/logs/errors_$(date +%Y%m%d).log
```

**War3Source takes a long time on first boot:** Normal — it compiles ~36 plugins from source on first start (~80 seconds). Subsequent boots use a compiled cache and start instantly.

**Server crashes with no logs:** Enable `TMUX_REMAIN_ON_EXIT=true` in `.env` to keep the tmux session alive after srcds crashes. Then attach to see the last output:

```bash
docker compose exec tf2classified tmux attach -t srcds
```

## Links

- TF2C Wiki server guide: https://wiki.tf2classic.com/wiki/Dedicated_Linux_server
- TF2C on Steam: https://store.steampowered.com/app/3545060
- SourceMod: https://www.sourcemod.net
- MetaMod:Source: https://www.metamodsource.net
- SMJansson (source): https://github.com/srcdslab/sm-ext-SMJansson
- SMJansson (64-bit build): https://forums.alliedmods.net/showthread.php?t=184604&page=8
- War3Source:EVO: https://github.com/War3Evo/War3Source-EVO
- VSH: https://github.com/Chdata/Versus-Saxton-Hale
- TF2Items: https://github.com/nosoop/SMExt-TF2Items
- MapChooser Extended: https://github.com/Totenfluch/sourcemod-mapchooser-extended
- NativeVotes: https://github.com/Heapons/sourcemod-nativevotes-updated
- Advertisements: https://github.com/ErikMinekus/sm-advertisements
- RTD: https://github.com/Phil25/RTD
- Round-Time: https://github.com/KatsuteTF/Round-Time
- Map Config (YAMCP): https://github.com/nosoop/SM-YetAnotherMapConfigPlugin
- TF2Attributes: https://github.com/FlaminSarge/tf2attributes
