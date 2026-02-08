#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Drop root privileges
# ---------------------------------------------------------------------------
# Multi-server deployments need per-server isolation of the shared game
# directory. When the /data/overlay volume is mounted, OverlayFS creates a
# copy-on-write layer so each server's writes (addon configs, sounds,
# gamedata patches, MOTD, SourceMod installs) are fully isolated.
# After setup, re-exec this script as the unprivileged srcds user.
if [[ "$(id -u)" == "0" ]]; then
    # Fix ownership of volume mount points Docker may have created as root
    for d in /data /data/tf /data/classified; do
        [[ -d "$d" ]] && chown srcds:srcds "$d"
    done

    # Per-server game directory isolation via OverlayFS
    if [[ -d /data/overlay ]] && [[ -d /data/classified/tf2classified ]]; then
        mkdir -p /data/overlay/upper /data/overlay/work
        chown -R srcds:srcds /data/overlay
        if mount -t overlay overlay \
            -o "lowerdir=/data/classified/tf2classified,upperdir=/data/overlay/upper,workdir=/data/overlay/work" \
            /data/classified/tf2classified 2>/dev/null; then
            echo "[INFO]  OverlayFS mounted — game directory writes are per-server"
        else
            echo "[WARN]  OverlayFS mount failed — add cap_add: SYS_ADMIN and security_opt: apparmor:unconfined"
            echo "[WARN]  Running without per-server isolation (single-server is fine, multi-server may have conflicts)"
        fi
    fi

    exec runuser -u srcds -- "$0" "$@"
fi

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
# Auto-update mode: immediate (default), graceful (warn players first), announce (notify only)
: "${AUTO_UPDATE_MODE:=immediate}"
# Grace period in seconds for graceful mode (players get warned before restart)
: "${UPDATE_GRACE_PERIOD:=60}"
# Keep tmux session alive after srcds exits (for crash debugging)
: "${TMUX_REMAIN_ON_EXIT:=false}"

# server.cfg mode: auto (default) or custom
: "${SERVER_CFG_MODE:=auto}"

# Mod download URLs — override in .env to pin versions, set to "skip" to disable
: "${MMS_URL:=https://mms.alliedmods.net/mmsdrop/2.0/mmsource-2.0.0-git1384-linux.tar.gz}"
: "${SM_URL:=https://sm.alliedmods.net/smdrop/1.13/sourcemod-1.13.0-git7293-linux.tar.gz}"
# SMJansson 64-bit is bundled in the image (upstream only ships 32-bit)
: "${INSTALL_MODS:=true}"

# Optional addons — set to "true" to enable (all disabled by default)
: "${ADDON_TF2ATTRIBUTES:=false}"
: "${ADDON_MAPCHOOSER_EXTENDED:=false}"
: "${ADDON_NATIVEVOTES:=false}"
: "${ADDON_ADVERTISEMENTS:=false}"
: "${ADDON_RTD:=false}"
: "${ADDON_VSH:=false}"
: "${ADDON_WAR3SOURCE:=false}"
: "${ADDON_ROUNDTIME:=false}"
: "${ADDON_MAPCONFIG:=false}"

# Addon download URLs — override to pin versions
: "${TF2ATTR_URL:=https://github.com/FlaminSarge/tf2attributes/releases/download/v1.7.5}"
: "${MCE_URL:=https://github.com/Totenfluch/sourcemod-mapchooser-extended/archive/refs/heads/master.tar.gz}"
: "${NATIVEVOTES_URL:=https://github.com/Heapons/sourcemod-nativevotes-updated/releases/download/workflow-build37/nativevotes_sm_1.13.zip}"
: "${ADVERTISEMENTS_URL:=https://github.com/ErikMinekus/sm-advertisements/releases/download/2.1.2/advertisements.zip}"
: "${RTD_URL:=https://github.com/Phil25/RTD/releases/download/2.5.5/rtd-2.5.5.zip}"
: "${VSH_URL:=https://github.com/Chdata/Versus-Saxton-Hale/archive/refs/heads/master.tar.gz}"
: "${TF2ITEMS_URL:=https://github.com/nosoop/SMExt-TF2Items/releases/download/r13-main/package.tar.gz}"
: "${WAR3SOURCE_URL:=https://github.com/War3Evo/War3Source-EVO/archive/refs/heads/master.tar.gz}"
: "${ROUNDTIME_URL:=https://github.com/KatsuteTF/Round-Time/releases/download/1.0/Time.smx}"

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

# Per-server config suffix — prevents servers sharing a volume from
# overwriting each other's server.cfg (race condition on startup).
CFG_SUFFIX="_${SERVER_PORT}"

# ---------------------------------------------------------------------------
# 1. Install / update game files via SteamCMD
# ---------------------------------------------------------------------------

# Check if an appmanifest is in a stuck/failed state (StateFlags=6, UpdateResult!=0)
# and remove it so SteamCMD can start fresh instead of immediately failing.
clear_stale_manifest() {
    local dir="$1" appid="$2"
    local manifest="${dir}/steamapps/appmanifest_${appid}.acf"

    if [[ ! -f "$manifest" ]]; then
        return 0
    fi

    local state_flags update_result
    state_flags=$(grep '"StateFlags"' "$manifest" 2>/dev/null | tr -dc '0-9')
    update_result=$(grep '"UpdateResult"' "$manifest" 2>/dev/null | tr -dc '0-9')

    # StateFlags=4 means fully installed and clean. Anything else (especially 6)
    # means a previous update was interrupted or failed.
    if [[ "${state_flags}" != "4" ]] || [[ -n "${update_result}" && "${update_result}" != "0" ]]; then
        log_warn "Stale manifest detected for AppID ${appid} (StateFlags=${state_flags}, UpdateResult=${update_result}) — removing to allow clean update"
        rm -f "$manifest"
    fi
}

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

    # Clear any stuck manifest from a previous failed update
    clear_stale_manifest "${dir}" "${appid}"

    local attempt
    for attempt in 1 2; do
        if "${STEAMCMD}" \
            +force_install_dir "${dir}" \
            +login anonymous \
            +app_update "${appid}" ${validate_flag} \
            +quit; then

            # Verify the manifest is actually clean after SteamCMD reports success
            local manifest="${dir}/steamapps/appmanifest_${appid}.acf"
            if [[ -f "$manifest" ]]; then
                local post_state
                post_state=$(grep '"StateFlags"' "$manifest" 2>/dev/null | tr -dc '0-9')
                if [[ "${post_state}" == "4" ]]; then
                    log_info "${label} update successful"
                    return 0
                fi
                # SteamCMD exited 0 but manifest is still dirty
                log_warn "${label} manifest still dirty after update (StateFlags=${post_state})"
            else
                # No manifest at all — first install, trust the exit code
                return 0
            fi
        else
            log_warn "SteamCMD exited non-zero for ${label} (attempt ${attempt})"
        fi

        # If first attempt failed, nuke the manifest and retry with validate
        if [[ "$attempt" == "1" ]]; then
            log_warn "Retrying ${label} update with validate after clearing manifest..."
            rm -f "${dir}/steamapps/appmanifest_${appid}.acf"
            validate_flag="validate"
        fi
    done

    log_error "SteamCMD failed for ${label} after 2 attempts — continuing anyway"
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
# 2. Install MetaMod / SourceMod / SMJansson (first run only)
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

    if [[ ! -f "${GAME_DIR}/addons/sourcemod/configs/core.cfg" ]]; then
        install_tarball "${SM_URL}" "SourceMod" "${GAME_DIR}"
    else
        log_info "SourceMod already present, skipping"
    fi

    # SMJansson: install bundled 64-bit build (upstream only ships 32-bit)
    if [[ -d "${GAME_DIR}/addons/sourcemod" ]]; then
        SMJ_SRC="/opt/addons-bundled/smjansson/smjansson.ext.so"
        SMJ_DST="${GAME_DIR}/addons/sourcemod/extensions/x64/smjansson.ext.so"
        if [[ -f "${SMJ_SRC}" ]]; then
            # Remove stale 32-bit copy from extensions root if present
            rm -f "${GAME_DIR}/addons/sourcemod/extensions/smjansson.ext.so"
            mkdir -p "${GAME_DIR}/addons/sourcemod/extensions/x64"
            if [[ ! -f "${SMJ_DST}" ]]; then
                cp "${SMJ_SRC}" "${SMJ_DST}" 2>/dev/null || true
                chmod 755 "${SMJ_DST}" 2>/dev/null || true
                log_info "Installed SMJansson (64-bit)"
            fi
            # Autoload marker must exist in extensions root for SM to load it
            touch "${GAME_DIR}/addons/sourcemod/extensions/smjansson.autoload"
        fi
    fi
fi

# ---------------------------------------------------------------------------
# 2b. Install optional addons (if any are enabled)
# ---------------------------------------------------------------------------
export ADDON_TF2ATTRIBUTES ADDON_MAPCHOOSER_EXTENDED ADDON_NATIVEVOTES
export ADDON_ADVERTISEMENTS ADDON_RTD ADDON_VSH ADDON_WAR3SOURCE
export ADDON_ROUNDTIME ADDON_MAPCONFIG
export TF2ATTR_URL MCE_URL NATIVEVOTES_URL ADVERTISEMENTS_URL RTD_URL
export VSH_URL TF2ITEMS_URL WAR3SOURCE_URL ROUNDTIME_URL
/opt/scripts/install-addons.sh "${GAME_DIR}" || log_warn "Addon installation had errors — server will start without some addons"

# ---------------------------------------------------------------------------
# 3. Link user content from /data bind mounts
# ---------------------------------------------------------------------------
log_step "Linking custom content..."

# Symlink all config files (.cfg, .txt, .ini — anything you might need)
if [[ -d "${SERVER_DATA}/cfg" ]]; then
    for f in "${SERVER_DATA}"/cfg/*; do
        [[ -f "$f" ]] || continue
        fname="$(basename "$f")"
        # motd files live in the game root, not cfg/
        if [[ "${fname,,}" == "motd.txt" || "${fname}" == "motd_default.txt" ]]; then
            ln -sf "$f" "${GAME_DIR}/${fname}"
        else
            ln -sf "$f" "${GAME_DIR}/cfg/${fname}"
        fi
    done
fi

# Link SourceMod config overrides (cfg/sourcemod/*.cfg)
# These override the defaults installed by SourceMod
if [[ -d "${SERVER_DATA}/cfg/sourcemod" ]]; then
    mkdir -p "${GAME_DIR}/cfg/sourcemod"
    for f in "${SERVER_DATA}"/cfg/sourcemod/*; do
        [[ -f "$f" ]] || continue
        ln -sf "$f" "${GAME_DIR}/cfg/sourcemod/$(basename "$f")"
    done
fi

# Link SourceMod configs overrides (addons/sourcemod/configs/)
# Addon plugins (Advertisements, MCE, RTD, VSH, etc.) store their config
# files here. Symlinks let users override them from data/addons/sourcemod/configs/
if [[ -d "${SERVER_DATA}/addons/sourcemod/configs" ]]; then
    mkdir -p "${GAME_DIR}/addons/sourcemod/configs"
    for f in "${SERVER_DATA}"/addons/sourcemod/configs/*; do
        [[ -e "$f" ]] || continue
        local_name="$(basename "$f")"
        if [[ -d "$f" ]]; then
            # Subdirectory (e.g. mapchooser_extended/, saxton_hale/)
            mkdir -p "${GAME_DIR}/addons/sourcemod/configs/${local_name}"
            for sub in "$f"/*; do
                [[ -f "$sub" ]] || continue
                ln -sf "$sub" "${GAME_DIR}/addons/sourcemod/configs/${local_name}/$(basename "$sub")"
            done
        else
            ln -sf "$f" "${GAME_DIR}/addons/sourcemod/configs/${local_name}"
        fi
    done
fi

# Guarantee MOTD files always exist — the Source engine reads cfg/MOTD.txt for
# the HTML MOTD panel shown on connect. Without it, players see stale cached
# content from other servers. We write both cfg/MOTD.txt and motd.txt (game root).
DEFAULT_MOTD='<html>
<body style="background:#1a1a2e;color:#e0e0e0;font-family:sans-serif;text-align:center;padding:40px">
<h1 style="color:#e94560">TF2 Classified</h1>
<p>Community Server</p>
</body>
</html>'

# cfg/MOTD.txt is the primary file the engine reads for the connect MOTD panel
if [[ -f "${GAME_DIR}/motd.txt" ]] || [[ -L "${GAME_DIR}/motd.txt" ]]; then
    # Use the per-server motd.txt content for cfg/MOTD.txt too
    cp -f "${GAME_DIR}/motd.txt" "${GAME_DIR}/cfg/MOTD.txt" 2>/dev/null || true
    log_info "Wrote cfg/MOTD.txt from per-server motd.txt"
else
    echo "${DEFAULT_MOTD}" > "${GAME_DIR}/motd.txt"
    echo "${DEFAULT_MOTD}" > "${GAME_DIR}/cfg/MOTD.txt"
    log_info "Wrote default MOTD files (no custom MOTD provided)"
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
# 3b. Auto-compress maps for FastDL
# ---------------------------------------------------------------------------
FASTDL_MAPS_DIR="${SERVER_DATA}/fastdl/tf2classified/maps"
if [[ -d "${SERVER_DATA}/maps" ]] && command -v bzip2 &>/dev/null; then
    shopt -s nullglob
    BSP_FILES=("${SERVER_DATA}"/maps/*.bsp)
    shopt -u nullglob

    if [[ ${#BSP_FILES[@]} -gt 0 ]]; then
        mkdir -p "${FASTDL_MAPS_DIR}" 2>/dev/null || true
        COMPRESSED=0
        for bsp in "${BSP_FILES[@]}"; do
            filename="$(basename "${bsp}")"
            # Copy raw .bsp if missing or source is newer
            if [[ ! -f "${FASTDL_MAPS_DIR}/${filename}" ]] || [[ "${bsp}" -nt "${FASTDL_MAPS_DIR}/${filename}" ]]; then
                cp "${bsp}" "${FASTDL_MAPS_DIR}/${filename}" 2>/dev/null || true
            fi
            # Compress if missing or source is newer
            if [[ ! -f "${FASTDL_MAPS_DIR}/${filename}.bz2" ]] || [[ "${bsp}" -nt "${FASTDL_MAPS_DIR}/${filename}.bz2" ]]; then
                bzip2 -kf "${FASTDL_MAPS_DIR}/${filename}" 2>/dev/null || true
                COMPRESSED=$((COMPRESSED + 1))
            fi
        done
        if [[ ${COMPRESSED} -gt 0 ]]; then
            log_info "FastDL: compressed ${COMPRESSED} new/updated map(s) in ${FASTDL_MAPS_DIR}"
        else
            log_info "FastDL: all ${#BSP_FILES[@]} map(s) already compressed"
        fi
    fi
elif [[ -d "${SERVER_DATA}/maps" ]] && ! command -v bzip2 &>/dev/null; then
    log_warn "bzip2 not found — skipping FastDL map compression"
fi

# ---------------------------------------------------------------------------
# 4. server.cfg — auto-generate from .env or leave alone
# ---------------------------------------------------------------------------
if [[ "${SERVER_CFG_MODE,,}" == "custom" ]]; then
    log_info "SERVER_CFG_MODE=custom — not writing server.cfg (you manage it)"
    if [[ ! -f "${GAME_DIR}/cfg/server.cfg" ]]; then
        log_warn "No server.cfg found! Put one in data/cfg/server.cfg or set SERVER_CFG_MODE=auto"
    fi
else
    # Remove stale shared server.cfg so the engine doesn't auto-load it
    rm -f "${GAME_DIR}/cfg/server.cfg"

    log_step "Writing server${CFG_SUFFIX}.cfg (SERVER_CFG_MODE=auto)..."

    cat > "${GAME_DIR}/cfg/server${CFG_SUFFIX}.cfg" << CFGEOF
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

# default cfg is loaded early — steam networking must be set before connect
cat > "${GAME_DIR}/cfg/default${CFG_SUFFIX}.cfg" << DEFEOF
sv_use_steam_networking ${STEAM_NET_CVAR}
DEFEOF

if [[ "${STEAM_NET_CVAR}" == "1" ]]; then
    log_info "Steam Datagram Relay ENABLED — your IP is hidden"
else
    log_warn "Steam Datagram Relay DISABLED — your IP is visible! Port ${SERVER_PORT}/UDP must be forwarded."
fi

[[ -n "${FASTDL_URL}" ]] && log_info "FastDL: ${FASTDL_URL}"

# ---------------------------------------------------------------------------
# 5. SourceMod admin
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
# 6. Launch
# ---------------------------------------------------------------------------
AUTO_UPDATE_CVAR=$(bool_to_cvar "${AUTO_UPDATE}")

# Random start map: if START_MAP contains a glob wildcard (*), pick a random
# matching .bsp from the maps directory. E.g. START_MAP=vsh_* picks a random VSH map.
if [[ "${START_MAP}" == *"*"* ]]; then
    shopt -s nullglob
    MATCHING_MAPS=()
    for bsp in "${GAME_DIR}"/maps/${START_MAP}.bsp; do
        MATCHING_MAPS+=("$(basename "${bsp%.bsp}")")
    done
    shopt -u nullglob
    if [[ ${#MATCHING_MAPS[@]} -gt 0 ]]; then
        RANDOM_IDX=$((RANDOM % ${#MATCHING_MAPS[@]}))
        START_MAP="${MATCHING_MAPS[$RANDOM_IDX]}"
        log_info "Random start map: ${START_MAP} (from ${#MATCHING_MAPS[@]} matching maps)"
    else
        log_warn "No maps matching '${START_MAP}' — falling back to ctf_2fort"
        START_MAP="ctf_2fort"
    fi
fi

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

# Show enabled addons
ACTIVE_ADDONS=""
[[ "${ADDON_TF2ATTRIBUTES,,}" == "true" ]] && ACTIVE_ADDONS+="tf2attributes "
[[ "${ADDON_MAPCHOOSER_EXTENDED,,}" == "true" ]] && ACTIVE_ADDONS+="MCE "
[[ "${ADDON_NATIVEVOTES,,}" == "true" ]] && ACTIVE_ADDONS+="NativeVotes "
[[ "${ADDON_ADVERTISEMENTS,,}" == "true" ]] && ACTIVE_ADDONS+="Ads "
[[ "${ADDON_RTD,,}" == "true" ]] && ACTIVE_ADDONS+="RTD "
[[ "${ADDON_VSH,,}" == "true" ]] && ACTIVE_ADDONS+="VSH "
[[ "${ADDON_WAR3SOURCE,,}" == "true" ]] && ACTIVE_ADDONS+="War3Source "
[[ "${ADDON_ROUNDTIME,,}" == "true" ]] && ACTIVE_ADDONS+="RoundTime "
[[ "${ADDON_MAPCONFIG,,}" == "true" ]] && ACTIVE_ADDONS+="MapConfig "
if [[ -n "${ACTIVE_ADDONS}" ]]; then
    echo "  Addons:     ${ACTIVE_ADDONS}"
else
    echo "  Addons:     none"
fi
echo ""
echo "============================================"
echo ""

# Symlink 64-bit steamclient.so into the Steam SDK directory.
# srcds_linux64 searches /home/srcds/.steam/sdk64/ for steamclient.so.
# Without it, Steam networking fails and the server runs in LAN-only mode.
STEAM_SDK64="/home/srcds/.steam/sdk64"
mkdir -p "${STEAM_SDK64}"
if [[ ! -f "${STEAM_SDK64}/steamclient.so" ]]; then
    for candidate in \
        "${CLASSIFIED_DIR}/bin/linux64/steamclient.so" \
        "${TF2_DIR}/bin/linux64/steamclient.so" \
        "/opt/steamcmd/linux64/steamclient.so"; do
        if [[ -f "${candidate}" ]]; then
            ln -sf "${candidate}" "${STEAM_SDK64}/steamclient.so"
            log_info "Linked 64-bit steamclient.so from ${candidate}"
            break
        fi
    done
fi

cd "${CLASSIFIED_DIR}"
export LD_LIBRARY_PATH=".:bin/linux64:${LD_LIBRARY_PATH:-}"
export AUTO_UPDATE_INTERVAL

# --- Signal handling ---
# srcds runs inside a tmux session so users can attach to its console
# interactively. Forward SIGTERM/SIGINT to the srcds process for graceful
# shutdown.
shutdown_server() {
    log_info "Shutting down server..."
    # Find the srcds process inside the tmux session
    local pid
    pid=$(tmux list-panes -t srcds -F '#{pane_pid}' 2>/dev/null) || true
    if [[ -n "${pid}" ]]; then
        kill -TERM "$pid" 2>/dev/null || true
        # Wait for it to exit
        while kill -0 "$pid" 2>/dev/null; do sleep 0.5; done
    fi
    tmux kill-session -t srcds 2>/dev/null || true
    exit 0
}
trap shutdown_server SIGTERM SIGINT

# --- Port allocation ---
# Each srcds instance binds 3 UDP ports: game, client, and SourceTV (HLTV).
# By default, client ports start at 27005 and SourceTV at game_port+5,
# which collide with other servers' game ports in multi-server setups.
# We offset them into safe ranges to prevent conflicts.
CLIENT_PORT=$((SERVER_PORT + 500))
TV_PORT=$((SERVER_PORT + 1000))

# --- Start srcds inside tmux ---
# Running inside tmux lets users attach to the live srcds console with:
#   docker compose exec <service> tmux attach -t srcds
SRCDS_CMD="./srcds_linux64 \
    -tf_path \"${TF2_DIR}\" \
    +map \"${START_MAP}\" \
    +maxplayers \"${MAX_PLAYERS}\" \
    -port \"${SERVER_PORT}\" \
    -clientport \"${CLIENT_PORT}\" \
    +tv_port \"${TV_PORT}\" \
    -tickrate \"${TICKRATE}\" \
    -console \
    -textconsole \
    -usercon \
    +servercfgfile server${CFG_SUFFIX}.cfg \
    +exec default${CFG_SUFFIX}.cfg \
    ${EXTRA_ARGS}"

tmux new-session -d -s srcds "$SRCDS_CMD"

# Keep tmux session alive after srcds exits (for crash debugging)
if [[ "${TMUX_REMAIN_ON_EXIT,,}" == "true" ]]; then
    tmux set-option -t srcds remain-on-exit on
    log_info "tmux remain-on-exit enabled (session persists after crash for debugging)"
fi

# Give tmux a moment to spawn the process
sleep 1
SRCDS_PID=$(tmux list-panes -t srcds -F '#{pane_pid}' 2>/dev/null) || true
log_info "srcds running in tmux session 'srcds' (PID ${SRCDS_PID:-unknown})"

# --- Start auto-update checker ---
if [[ "${AUTO_UPDATE_CVAR}" == "1" ]]; then
    if [[ -n "${SRCDS_PID}" ]]; then
        export AUTO_UPDATE_MODE UPDATE_GRACE_PERIOD RCON_PASSWORD SERVER_PORT
        /opt/scripts/auto-update.sh "$SRCDS_PID" &
        log_info "Auto-update checker started (every ${AUTO_UPDATE_INTERVAL}s, mode: ${AUTO_UPDATE_MODE})"
    else
        log_warn "Could not determine srcds PID — auto-update disabled"
    fi
fi

# --- Wait for tmux session to end ---
# Poll the tmux session instead of bash wait, since srcds is a tmux child.
while tmux has-session -t srcds 2>/dev/null; do
    sleep 2
done

log_info "Server exited"
exit 0
