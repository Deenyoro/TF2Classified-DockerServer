#!/usr/bin/env bash
# auto-update.sh — Background update checker for TF2 Classified
#
# Periodically compares local vs remote build IDs using SteamCMD.
# When an update is detected, sends SIGTERM to srcds so the container
# exits and Docker restarts it. The entrypoint's UPDATE_ON_START then
# applies the update via SteamCMD before relaunching the server.
#
# Usage: auto-update.sh <srcds_pid>
#   Started automatically by entrypoint.sh when AUTO_UPDATE=true.

set -uo pipefail
# NOTE: no set -e — we don't want a transient Steam API failure to kill the checker

: "${STEAMCMD_DIR:=/opt/steamcmd}"
: "${TF2_DIR:=/data/tf}"
: "${CLASSIFIED_DIR:=/data/classified}"
: "${AUTO_UPDATE_INTERVAL:=300}"
: "${UPDATE_GAME_FILES:=true}"

STEAMCMD="${STEAMCMD_DIR}/steamcmd.sh"
SRCDS_PID="$1"

CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'
log()  { echo -e "${CYAN}[AUTO-UPDATE]${NC} $1"; }
warn() { echo -e "${YELLOW}[AUTO-UPDATE]${NC} $1"; }

# ---------------------------------------------------------------------------
# Build ID helpers
# ---------------------------------------------------------------------------

# Read local build ID from SteamCMD's appmanifest_<appid>.acf
# SteamCMD stores these in its own steamapps/ dir when using +force_install_dir
get_local_buildid() {
    local appid="$1"
    local manifest=""

    for path in \
        "${STEAMCMD_DIR}/steamapps/appmanifest_${appid}.acf" \
        "${CLASSIFIED_DIR}/steamapps/appmanifest_${appid}.acf" \
        "${TF2_DIR}/steamapps/appmanifest_${appid}.acf"; do
        if [[ -f "$path" ]]; then
            manifest="$path"
            break
        fi
    done

    if [[ -z "$manifest" ]]; then
        echo ""
        return
    fi

    grep '"buildid"' "$manifest" 2>/dev/null | head -1 | tr -dc '0-9'
}

# Query Steam for the latest public branch build ID
get_remote_buildid() {
    local appid="$1"
    "${STEAMCMD}" +login anonymous +app_info_update 1 +app_info_print "$appid" +quit 2>/dev/null \
        | grep -A3 '"public"' | grep '"buildid"' | head -1 | tr -dc '0-9' || echo ""
}

# Returns 0 if an update is available, 1 otherwise
check_app() {
    local appid="$1" label="$2"

    local local_id
    local_id=$(get_local_buildid "$appid")

    if [[ -z "$local_id" ]]; then
        # No manifest found — can't compare, skip
        return 1
    fi

    local remote_id
    remote_id=$(get_remote_buildid "$appid")

    if [[ -z "$remote_id" ]]; then
        warn "Could not reach Steam to check ${label} — will retry next cycle"
        return 1
    fi

    if [[ "$local_id" != "$remote_id" ]]; then
        log "${label} update detected! (build ${local_id} → ${remote_id})"
        return 0
    fi

    return 1
}

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------
log "Started (checking every ${AUTO_UPDATE_INTERVAL}s)"

while true; do
    sleep "${AUTO_UPDATE_INTERVAL}"

    # If srcds died on its own, no point continuing
    if ! kill -0 "$SRCDS_PID" 2>/dev/null; then
        log "srcds no longer running, exiting"
        exit 0
    fi

    update_found=false

    if [[ "${UPDATE_GAME_FILES,,}" == "true" ]]; then
        if check_app "3557020" "TF2 Classified"; then
            update_found=true
        elif check_app "232250" "TF2 Dedicated Server (base)"; then
            update_found=true
        fi
    fi

    if $update_found; then
        warn "Stopping server for update — container will restart automatically..."
        kill -TERM "$SRCDS_PID" 2>/dev/null || true
        # The entrypoint will catch srcds exiting and the container will restart.
        # UPDATE_ON_START in the new entrypoint run will apply the update.
        exit 0
    fi
done
