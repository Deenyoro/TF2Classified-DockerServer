#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# TF2 Classified Dedicated Server — Container Entrypoint
# ---------------------------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()  { echo -e "${CYAN}[STEP]${NC}  $1"; }

echo ""
echo "============================================"
echo "   TF2 Classified Dedicated Server"
echo "============================================"
echo ""

# ---------------------------------------------------------------------------
# Environment defaults (override via .env)
# ---------------------------------------------------------------------------
: "${STEAMCMD_DIR:=/opt/steamcmd}"
: "${TF2_DIR:=/data/tf}"
: "${CLASSIFIED_DIR:=/data/classified}"
: "${SERVER_DATA:=/data}"

: "${SERVER_NAME:=TF2 Classified Server}"
: "${SERVER_PASSWORD:=}"
: "${RCON_PASSWORD:=changeme}"
: "${SERVER_PORT:=27015}"
: "${MAX_PLAYERS:=24}"
: "${START_MAP:=ctf_2fort}"
: "${TICKRATE:=66}"

: "${STEAM_NETWORKING:=true}"
: "${UPDATE_ON_START:=true}"
: "${UPDATE_GAME_FILES:=true}"
: "${VALIDATE_INSTALL:=0}"

: "${SM_ADMIN_STEAMID:=}"
: "${SV_TAGS:=}"
: "${EXTRA_ARGS:=}"
: "${FASTDL_URL:=}"

# Auto-update: polls Steam for new builds while server is running
: "${AUTO_UPDATE:=true}"
: "${AUTO_UPDATE_INTERVAL:=300}"

# server.cfg mode: auto (default) or custom
: "${SERVER_CFG_MODE:=auto}"

# Mod download URLs — override in .env to pin versions, set to "skip" to disable
: "${MMS_URL:=https://mms.alliedmods.net/mmsdrop/2.0/mmsource-2.0.0-git1383-linux.tar.gz}"
: "${SM_URL:=https://sm.alliedmods.net/smdrop/1.13/sourcemod-1.13.0-git7291-linux.tar.gz}"
: "${SMJANSSON_URL:=https://github.com/srcdslab/sm-ext-SMJansson/releases/download/2.6.1/sm-ext-SMJansson-2.6.1-linux.tar.gz}"
: "${INSTALL_MODS:=true}"

STEAMCMD="${STEAMCMD_DIR}/steamcmd.sh"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
bool_to_cvar() {
    case "${1,,}" in
        true|1|yes|on) echo "1" ;;
        *) echo "0" ;;
    esac
}

STEAM_NET_CVAR=$(bool_to_cvar "${STEAM_NETWORKING}")

# ---------------------------------------------------------------------------
# 1. Install / update game files via SteamCMD
# ---------------------------------------------------------------------------
install_or_update() {
    local dir="$1" appid="$2" label="$3"
    local validate_flag=""
    [[ "${VALIDATE_INSTALL}" == "1" ]] && validate_flag="validate"

    local needs_install=false
    if [[ "${appid}" == "3557020" ]]; then
        [[ ! -f "${dir}/srcds_linux64" ]] && needs_install=true
    else
        [[ ! -d "${dir}/tf" ]] && needs_install=true
    fi

    if ${needs_install}; then
        log_step "Installing ${label} (AppID ${appid}) — first run, downloading several GB..."
    elif [[ "${UPDATE_ON_START}" == "true" ]]; then
        log_step "Checking for updates: ${label} (AppID ${appid})..."
    else
        log_info "${label} already installed, UPDATE_ON_START=false, skipping"
        return 0
    fi

    "${STEAMCMD}" \
        +force_install_dir "${dir}" \
        +login anonymous \
        +app_update "${appid}" ${validate_flag} \
        +quit || {
            log_error "SteamCMD failed for ${label} — continuing anyway"
        }
}

mkdir -p "${TF2_DIR}" "${CLASSIFIED_DIR}"

if [[ "${UPDATE_GAME_FILES,,}" == "true" ]]; then
    install_or_update "${TF2_DIR}"        "232250"  "TF2 Dedicated Server (base)"
    install_or_update "${CLASSIFIED_DIR}" "3557020" "TF2 Classified"
else
    if [[ ! -d "${TF2_DIR}/tf" ]] || [[ ! -f "${CLASSIFIED_DIR}/srcds_linux64" ]]; then
        log_error "Game files not found and UPDATE_GAME_FILES=false — start the primary server first"
        exit 1
    fi
    log_info "UPDATE_GAME_FILES=false — skipping downloads (shared volumes, primary server handles updates)"
fi

# ---------------------------------------------------------------------------
# 2. Library symlinks — required or the server flat out won't work
#
# See: https://wiki.tf2classic.com/wiki/Dedicated_Linux_server
# ---------------------------------------------------------------------------
log_step "Fixing library symlinks..."

# steamclient.so -> ~/.steam/sdk64/
mkdir -p /home/srcds/.steam/sdk64
if [[ -f "${CLASSIFIED_DIR}/linux64/steamclient.so" ]]; then
    ln -sf "${CLASSIFIED_DIR}/linux64/steamclient.so" /home/srcds/.steam/sdk64/steamclient.so
fi

# libvstdlib.so -> libvstdlib_srv.so
# Without this: missing sounds, only stock weapons usable
if [[ -d "${CLASSIFIED_DIR}/bin/linux64" ]]; then
    (cd "${CLASSIFIED_DIR}/bin/linux64" && rm -f libvstdlib.so && ln -sf libvstdlib_srv.so libvstdlib.so)
fi

# server_srv.so -> server.so
if [[ -d "${CLASSIFIED_DIR}/tf2classified/bin/linux64" ]]; then
    (cd "${CLASSIFIED_DIR}/tf2classified/bin/linux64" && ln -sf server.so server_srv.so)
fi

# ---------------------------------------------------------------------------
# 3. Install MetaMod / SourceMod / SMJansson (first run only)
# ---------------------------------------------------------------------------
GAME_DIR="${CLASSIFIED_DIR}/tf2classified"

install_tarball() {
    local url="$1" label="$2" dest="$3"
    if [[ -z "${url}" || "${url}" == "skip" ]]; then
        log_info "Skipping ${label} (disabled)"
        return 0
    fi
    log_step "Downloading ${label}..."
    local tmp
    tmp="$(mktemp -d)"
    if curl -fsSL "${url}" -o "${tmp}/pkg.tar.gz"; then
        if ! tar -xzf "${tmp}/pkg.tar.gz" -C "${dest}"; then
            log_warn "Extraction warnings for ${label} — check logs"
        fi
    else
        log_warn "Download failed for ${label} — skipping"
    fi
    rm -rf "${tmp}"
}

if [[ "${INSTALL_MODS}" == "true" ]]; then
    if [[ ! -d "${GAME_DIR}/addons/metamod" ]]; then
        install_tarball "${MMS_URL}" "MetaMod:Source" "${GAME_DIR}"

        # metamod.vdf tells the engine to load MetaMod
        mkdir -p "${GAME_DIR}/addons"
        cat > "${GAME_DIR}/addons/metamod.vdf" << 'VDFEOF'
"Plugin"
{
	"file"	"../tf2classified/addons/metamod/bin/linux64/server"
}
VDFEOF
        log_info "Wrote metamod.vdf"
    else
        log_info "MetaMod already present, skipping"
    fi

    if [[ ! -d "${GAME_DIR}/addons/sourcemod" ]]; then
        install_tarball "${SM_URL}" "SourceMod" "${GAME_DIR}"
    else
        log_info "SourceMod already present, skipping"
    fi

    if [[ -d "${GAME_DIR}/addons/sourcemod" ]] && \
       [[ ! -f "${GAME_DIR}/addons/sourcemod/extensions/smjansson.ext.so" ]]; then
        install_tarball "${SMJANSSON_URL}" "SMJansson" "${GAME_DIR}/addons/sourcemod"
    fi
fi

# ---------------------------------------------------------------------------
# 4. Link user content from /data bind mounts
# ---------------------------------------------------------------------------
log_step "Linking custom content..."

# Symlink all config files (.cfg, .txt, .ini — anything you might need)
if [[ -d "${SERVER_DATA}/cfg" ]]; then
    for f in "${SERVER_DATA}"/cfg/*; do
        [[ -f "$f" ]] || continue
        ln -sf "$f" "${GAME_DIR}/cfg/$(basename "$f")"
    done
fi

if [[ -d "${SERVER_DATA}/maps" ]]; then
    for bsp in "${SERVER_DATA}"/maps/*.bsp; do
        [[ -f "$bsp" ]] || continue
        ln -sf "$bsp" "${GAME_DIR}/maps/$(basename "$bsp")"
    done
fi

if [[ -d "${SERVER_DATA}/addons" ]] && [[ "$(ls -A "${SERVER_DATA}/addons" 2>/dev/null)" ]]; then
    cp -rn "${SERVER_DATA}/addons/"* "${GAME_DIR}/addons/" 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# 5. server.cfg — auto-generate from .env or leave alone
# ---------------------------------------------------------------------------
if [[ "${SERVER_CFG_MODE,,}" == "custom" ]]; then
    log_info "SERVER_CFG_MODE=custom — not writing server.cfg (you manage it)"
    if [[ ! -f "${GAME_DIR}/cfg/server.cfg" ]]; then
        log_warn "No server.cfg found! Put one in data/cfg/server.cfg or set SERVER_CFG_MODE=auto"
    fi
else
    log_step "Writing server.cfg (SERVER_CFG_MODE=auto)..."

    cat > "${GAME_DIR}/cfg/server.cfg" << CFGEOF
// TF2 Classified Server Configuration
// Written from .env on container start. Gets overwritten every boot.
// Put your overrides in data/cfg/server_custom.cfg or switch to
// SERVER_CFG_MODE=custom in .env to manage this file yourself.

hostname "${SERVER_NAME}"
sv_password "${SERVER_PASSWORD}"
rcon_password "${RCON_PASSWORD}"

sv_use_steam_networking ${STEAM_NET_CVAR}
sv_maxrate 0
sv_minrate 0
sv_maxupdaterate 66
sv_minupdaterate 10

sv_tags "${SV_TAGS}"

mp_autoteambalance 1
mp_teams_unbalance_limit 1
mp_timelimit 30

sv_pure 1
sv_cheats 0

log on
sv_logbans 1
sv_logecho 1
sv_logfile 1

sv_allowdownload 1
sv_allowupload 1
net_maxfilesize 64
$(if [[ -n "${FASTDL_URL}" ]]; then
    echo "sv_downloadurl \"${FASTDL_URL}\""
else
    echo "// sv_downloadurl not set — set FASTDL_URL in .env for fast HTTP map downloads"
fi)

exec server_custom.cfg
CFGEOF
fi

# default.cfg is loaded before server.cfg — steam networking must be set early
cat > "${GAME_DIR}/cfg/default.cfg" << DEFEOF
sv_use_steam_networking ${STEAM_NET_CVAR}
DEFEOF

if [[ "${STEAM_NET_CVAR}" == "1" ]]; then
    log_info "Steam Datagram Relay ENABLED — your IP is hidden"
else
    log_warn "Steam Datagram Relay DISABLED — your IP is visible! Port ${SERVER_PORT}/UDP must be forwarded."
fi

[[ -n "${FASTDL_URL}" ]] && log_info "FastDL: ${FASTDL_URL}"

# ---------------------------------------------------------------------------
# 6. SourceMod admin
# ---------------------------------------------------------------------------
if [[ -n "${SM_ADMIN_STEAMID}" ]]; then
    ADMIN_FILE="${GAME_DIR}/addons/sourcemod/configs/admins_simple.ini"
    if [[ -f "${ADMIN_FILE}" ]]; then
        IFS=',' read -ra ADMIN_IDS <<< "${SM_ADMIN_STEAMID}"
        for sid in "${ADMIN_IDS[@]}"; do
            sid="$(echo "$sid" | xargs)"  # trim whitespace
            [[ -z "$sid" ]] && continue
            if ! grep -qF "$sid" "${ADMIN_FILE}" 2>/dev/null; then
                echo "\"${sid}\" \"99:z\"" >> "${ADMIN_FILE}"
                log_info "Added SourceMod admin: ${sid}"
            fi
        done
    fi
fi

# ---------------------------------------------------------------------------
# 7. Launch
# ---------------------------------------------------------------------------
AUTO_UPDATE_CVAR=$(bool_to_cvar "${AUTO_UPDATE}")

echo ""
echo "  Server:     ${SERVER_NAME}"
echo "  Map:        ${START_MAP}"
echo "  Players:    ${MAX_PLAYERS}"
echo "  Port:       ${SERVER_PORT}"
echo "  Tickrate:   ${TICKRATE}"
echo "  SDR:        $([ "${STEAM_NET_CVAR}" = "1" ] && echo "on (IP hidden)" || echo "off (direct)")"
echo "  Config:     ${SERVER_CFG_MODE}"
[[ -n "${FASTDL_URL}" ]] && echo "  FastDL:     ${FASTDL_URL}"
echo "  Auto-update: $([ "${AUTO_UPDATE_CVAR}" = "1" ] && echo "on (every ${AUTO_UPDATE_INTERVAL}s)" || echo "off")"
echo ""
echo "============================================"
echo ""

cd "${CLASSIFIED_DIR}"
export LD_LIBRARY_PATH=".:bin/linux64:${LD_LIBRARY_PATH:-}"
export AUTO_UPDATE_INTERVAL

# --- Signal handling ---
# We run srcds in the background so the auto-update checker can run
# alongside it. Forward SIGTERM/SIGINT to srcds for graceful shutdown.
SRCDS_PID=""
shutdown_server() {
    if [[ -n "${SRCDS_PID}" ]]; then
        log_info "Shutting down server..."
        kill -TERM "$SRCDS_PID" 2>/dev/null || true
        wait "$SRCDS_PID" 2>/dev/null || true
    fi
    exit 0
}
trap shutdown_server SIGTERM SIGINT

# --- Start srcds ---
./srcds_linux64 \
    -tf_path "${TF2_DIR}" \
    +map "${START_MAP}" \
    +maxplayers "${MAX_PLAYERS}" \
    -port "${SERVER_PORT}" \
    -tickrate "${TICKRATE}" \
    -console \
    -usercon \
    +exec server.cfg \
    ${EXTRA_ARGS} &
SRCDS_PID=$!

# --- Start auto-update checker ---
if [[ "${AUTO_UPDATE_CVAR}" == "1" ]]; then
    /opt/scripts/auto-update.sh "$SRCDS_PID" &
    log_info "Auto-update checker started (every ${AUTO_UPDATE_INTERVAL}s)"
fi

# --- Wait for srcds to exit ---
wait "$SRCDS_PID"
EXIT_CODE=$?
log_info "Server exited (code ${EXIT_CODE})"
exit $EXIT_CODE
