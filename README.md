# TF2 Classified Docker Server

Dockerized TF2 Classified dedicated server. Edit `.env`, run `docker compose up -d`, done.

- IP hidden by default (Steam Datagram Relay)
- Optional playit.gg tunnel for stable address + server favoriting
- Auto-updates both TF2 base and TF2 Classified (checks while running, restarts automatically)
- MetaMod:Source, SourceMod, and SMJansson pre-installed
- All config in `.env`, custom content in `data/`

## Quick Start

```bash
cd tf2classified-docker
chmod +x setup.sh && ./setup.sh   # creates dirs, generates .env with random RCON pass
nano .env                          # tweak to your liking
docker compose up -d               # build + run
docker compose logs -f             # watch it (first boot downloads ~20GB)
```

Or just use `make setup && make start && make logs`.

## How Players Connect

**Steam Networking on (default):** Your server shows up in the TF2 Classified server browser. Players search by name and click join. They can't connect by IP and can't favorite it — the relay address changes.

**playit.gg:** Players get a fixed address like `something.playit.gg:12345`. They can paste it in console (`connect ...`) and add it to favorites. Your real IP is still hidden behind playit's servers.

**Direct (no relay, no tunnel):** Players connect by your public IP. You need to port-forward 27015/UDP. Your IP is exposed.

Quick comparison:

| | IP Hidden | Favoritable | Port Forward |
|-|-----------|-------------|-------------|
| Steam Networking (default) | yes | no | no |
| playit.gg | yes | yes | no |
| Direct | no | yes | yes |

## Setting Up playit.gg

Only do this if you want players to be able to favorite your server. Otherwise Steam Networking is fine and requires zero setup.

1. Create a free account at https://playit.gg
2. Add a **UDP tunnel** pointing to `127.0.0.1:27015`
3. Copy your secret key
4. In `.env`:
   ```
   STEAM_NETWORKING=false
   PLAYIT_SECRET_KEY=your-key-here
   ```
5. Start with the playit profile:
   ```bash
   docker compose --profile playit up -d
   ```
6. Share the playit.gg address with players

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
| `AUTO_UPDATE` | `true` | Poll Steam for updates while running; restart automatically |
| `AUTO_UPDATE_INTERVAL` | `300` | Seconds between update checks (default: 5 min) |
| `SERVER_CFG_MODE` | `auto` | `auto` = rebuild server.cfg from .env every boot. `custom` = you manage server.cfg yourself |
| `SM_ADMIN_STEAMID` | *(empty)* | Your Steam ID for SM admin |
| `SV_TAGS` | *(empty)* | Server browser tags |

Mod URLs (`MMS_URL`, `SM_URL`, `SMJANSSON_URL`) default to known-good 64-bit Linux builds. Set any of them to `skip` to not install that component. Set `INSTALL_MODS=false` to skip everything.

## Auto-Updates

The server handles game updates automatically with no manual intervention:

1. **On start** (`UPDATE_ON_START=true`): SteamCMD checks for and applies any pending updates before the server launches.
2. **While running** (`AUTO_UPDATE=true`): A background checker polls Steam every `AUTO_UPDATE_INTERVAL` seconds (default: 300 = 5 min). When a new build is detected for TF2 Classified or the TF2 base, it gracefully stops the server. Docker's `restart: unless-stopped` policy restarts the container, and step 1 applies the update.

The update flow: game update drops → checker detects build ID mismatch within minutes → server stops → container restarts → SteamCMD updates → server relaunches on new version.

Set `AUTO_UPDATE=false` to disable background checking (the server still updates on restart via `UPDATE_ON_START`).

## Custom Map Downloads (FastDL)

When players join your server with a custom map they don't have, Source normally sends the file through the game connection — slow and unreliable. FastDL tells the client to download it via HTTP instead.

### How it works

1. Player connects, doesn't have the map
2. Server says "download from this URL" (`sv_downloadurl`)
3. Client fetches `.bsp.bz2` via HTTP (fast), falls back to raw `.bsp`
4. Player loads in

### Setup

**Step 1 — Prepare maps:**

```bash
# Drop custom .bsp files into data/maps/ (server loads them from here)
cp my_custom_map.bsp data/maps/

# Compress for FastDL (copies + bzip2 to data/fastdl/tf2classified/maps/)
make compress-maps
```

**Step 2 — Choose a host:**

| Host | Cost | Setup |
|------|------|-------|
| **Cloudflare R2** (recommended) | Free (10GB, unlimited bandwidth) | Create bucket, enable public access, upload `data/fastdl/` contents |
| **Self-hosted nginx** (included) | Your bandwidth | `docker compose --profile fastdl up -d`, forward port 8080 |
| **Backblaze B2** | Free (10GB) | S3-compatible, upload `data/fastdl/` contents |
| **GitHub Releases** | Free (2GB per release) | Upload `.bsp.bz2` files to a release |

**Step 3 — Configure:**

```env
# .env
FASTDL_URL=https://pub-xxxxx.r2.dev/tf2classified
# or for self-hosted:
FASTDL_URL=http://your-ip:8080/tf2classified
```

Restart: `docker compose restart`

### FastDL directory structure

Your web root must mirror the game directory:

```
data/fastdl/
  tf2classified/
    maps/
      custom_map.bsp
      custom_map.bsp.bz2
    materials/...
    models/...
    sound/...
```

### Notes

- Upload **both** `.bsp` and `.bsp.bz2` — clients try compressed first, fall back to raw
- The `sv_downloadurl` value **must be quoted** in cfg files (the `//` in URLs looks like a comment). The entrypoint handles this automatically.
- `.res` files (resource lists for loose custom assets) belong on the game server, not on FastDL
- Best practice: pack custom assets into the BSP itself when possible

## Custom Content

**Configs:** Drop `.cfg` files in `data/cfg/`. They get symlinked into the game dir on start.

By default (`SERVER_CFG_MODE=auto`), `server.cfg` is rebuilt from `.env` on every boot. Don't edit it directly — put your overrides in `data/cfg/server_custom.cfg` instead (it gets `exec`'d at the end of `server.cfg`).

If you want full control, set `SERVER_CFG_MODE=custom` in `.env`. The entrypoint won't touch `server.cfg` at all — put your own in `data/cfg/server.cfg` and it gets symlinked into the game directory.

**Maps:** Drop `.bsp` files in `data/maps/`. For players to auto-download custom maps you need a FastDL server — set `sv_downloadurl` in your custom config.

**SourceMod plugins:** Drop `.smx` files in `data/addons/sourcemod/plugins/`.

**SourceMod admin:** Set `SM_ADMIN_STEAMID=STEAM_0:1:12345678` in `.env` (find yours at https://steamid.io).

## Running Multiple Servers

You can run multiple TF2C servers on the same host. They share all game files (~20GB) so nothing gets re-downloaded. Each additional server only needs its own port, name, and configs.

```bash
# Set up server 2 (creates dirs, .env.server2 with unique port + RCON)
make add-server N=2

# Edit its config
nano .env.server2

# Start it (primary server must already be running)
make start-server N=2

# Tail its logs
make logs-server N=2
```

The key differences in each server's `.env`: `UPDATE_GAME_FILES=false` (the primary server owns the shared game files) and a unique `SERVER_PORT` (27016, 27017, etc.).

Server 2 is pre-defined in `docker-compose.yml`. To add a third server, duplicate the `tf2classified-2` service block, change `2` to `3`, and add `classified-3-data` to the volumes section.

Each server's custom content lives in `servers/N/` instead of `data/`:

```
servers/
  2/
    cfg/            # server 2 configs
    addons/         # server 2 plugins
    maps/           # server 2 custom maps
    logs/
    demos/
```

## Server Management

```bash
docker compose logs -f                                    # tail logs
docker attach tf2classified                               # server console (Ctrl+P, Ctrl+Q to detach)
docker compose exec tf2classified /opt/scripts/update.sh  # manual update
docker compose restart                                    # restart (re-checks updates if enabled)
docker compose down                                       # stop
docker compose build --no-cache && docker compose up -d   # full rebuild
```

## What Gets Installed

The image itself is small (~500MB) — just Debian, SteamCMD, and runtime libraries. Game files download into Docker named volumes on first boot:

- **AppID 232250** — TF2 Dedicated Server (base dependency, ~15GB)
- **AppID 3557020** — TF2 Classified (~5GB)

On first run the entrypoint also installs:

- **MetaMod:Source 2.0** (build 1383) — TF2C requires >= 1380
- **SourceMod 1.13** (build 7291) — this build includes TF2 Classified gamedata
- **SMJansson 2.6.1** (64-bit) — JSON extension, needed by some plugins

These only install once. They won't re-download on subsequent starts unless you delete the `classified-data` volume.

## Library Symlinks

TF2 Classified requires three symlinks or it won't start / will have broken audio and weapons. The entrypoint re-applies them on every boot:

- `bin/linux64/libvstdlib.so` -> `libvstdlib_srv.so` (without this: no sounds, stock weapons only)
- `tf2classified/bin/linux64/server_srv.so` -> `server.so`
- `~/.steam/sdk64/steamclient.so` -> server's `linux64/steamclient.so`

If you see "sounds are missing" or "only stock weapons work", it's this symlink being broken. Usually means a volume mount overwrote the binary directory.

## File Layout

```
tf2classified-docker/
  Dockerfile              image build (deps + SteamCMD only)
  docker-compose.yml      services + fastdl/playit profiles
  .env.example            config template
  .env                    your config (generated by setup.sh)
  .gitignore              keeps data/, .env, logs out of version control
  setup.sh                first-time setup
  Makefile                convenience targets
  nginx/
    fastdl.conf           nginx config for self-hosted FastDL
  scripts/
    entrypoint.sh         startup: install, symlinks, config gen, launch
    update.sh             manual game file update
    auto-update.sh        background update checker (polls Steam)
    compress-maps.sh      bzip2-compress maps for FastDL
  .env.server2.example    config template for additional servers
  data/                   your persistent content (created by setup.sh)
    cfg/                  custom .cfg files
    addons/               SM plugins, etc.
    maps/                 custom .bsp maps
    fastdl/               FastDL web root (mirrored game structure)
    logs/                 server logs
    demos/                demo recordings
  servers/                per-server content (created by make add-server)
    2/cfg/                server 2 configs
    2/addons/             server 2 plugins
    2/maps/               ...
```

## Server Verification

Once your server is up and stable, you can ask the TF2 Classified team for manual verification. Verified servers get a "Verified" tag in the browser. After verification you can use type tags in `SV_TAGS`:

- `type_customrules` — drastic ruleset changes (civilian, bhop, custom gamemodes)
- `type_customweapons` — custom weapon packs, rebalances, throwback

## Troubleshooting

**Server not in browser:** With Steam Networking, it can take a few minutes to show up. Without it, make sure 27015/UDP is forwarded.

**Missing sounds / stock weapons only:** Broken `libvstdlib.so` symlink. The entrypoint should fix this automatically. If it persists, exec into the container and re-run the symlinks manually:
```bash
docker compose exec tf2classified bash
cd /data/classified/bin/linux64 && rm -f libvstdlib.so && ln -s libvstdlib_srv.so libvstdlib.so
```

**SourceMod not loading:** Check logs for download errors. Verify metamod.vdf exists:
```bash
docker compose exec tf2classified cat /data/classified/tf2classified/addons/metamod.vdf
```

**Container exits immediately on first run:** It's downloading ~20GB. Watch with `docker compose logs -f`. If SteamCMD keeps failing, set `VALIDATE_INSTALL=1` in `.env`.

## Links

- TF2 Classified Wiki server guide: https://wiki.tf2classic.com/wiki/Dedicated_Linux_server
- TF2 Classified on Steam: https://store.steampowered.com/app/3545060
- SourceMod: https://www.sourcemod.net
- MetaMod:Source: https://www.metamodsource.net
- SMJansson (srcdslab): https://github.com/srcdslab/sm-ext-SMJansson
- playit.gg: https://playit.gg
