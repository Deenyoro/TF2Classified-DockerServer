#!/usr/bin/env bash
# auto-update.sh — Background update checker for TF2 Classified
#
# Periodically compares local vs remote build IDs using SteamCMD.
# When an update is detected, behavior depends on AUTO_UPDATE_MODE:
#
#   immediate  — Stop server right away (default, current behavior)
#   graceful   — Warn players in-game, wait UPDATE_GRACE_PERIOD seconds, then stop
#   announce   — Warn players but don't auto-restart; wait for manual intervention
#
# Usage: auto-update.sh <srcds_pid>
#   Started automatically by entrypoint.sh when AUTO_UPDATE=true.

set -uo pipefail
# NOTE: no set -e — we don't want a transient Steam API failure to kill the checker

: "${STEAMCMD_DIR:=/opt/steamcmd}"
: "${TF2_DIR:=/data/tf}"
: "${CLASSIFIED_DIR:=/data/classified}"
: "${AUTO_UPDATE_INTERVAL:=300}"
: "${AUTO_UPDATE_MODE:=immediate}"
: "${UPDATE_GRACE_PERIOD:=60}"
: "${UPDATE_GAME_FILES:=true}"
: "${RCON_PASSWORD:=}"
: "${SERVER_PORT:=27015}"

STEAMCMD="${STEAMCMD_DIR}/steamcmd.sh"
SRCDS_PID="$1"

# Grace period extension file — touch this to add more time
EXTEND_FILE="/tmp/extend_update_grace"

CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
log()  { echo -e "${CYAN}[AUTO-UPDATE]${NC} $1"; }
warn() { echo -e "${YELLOW}[AUTO-UPDATE]${NC} $1"; }
error() { echo -e "${RED}[AUTO-UPDATE]${NC} $1"; }

# ---------------------------------------------------------------------------
# RCON helper — send command to srcds via tmux (more reliable than rcon cli)
# ---------------------------------------------------------------------------
rcon_cmd() {
    local cmd="$1"
    tmux send-keys -t srcds "$cmd" Enter 2>/dev/null || true
}

# Send chat message to all players
say_chat() {
    local msg="$1"
    rcon_cmd "say $msg"
}

# ---------------------------------------------------------------------------
# Build ID helpers
# ---------------------------------------------------------------------------

# Read local build ID from SteamCMD's appmanifest_<appid>.acf
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
# Graceful shutdown with player warning
# ---------------------------------------------------------------------------
graceful_shutdown() {
    local grace_seconds="${UPDATE_GRACE_PERIOD}"
    local remaining="$grace_seconds"

    # Remove any stale extend file
    rm -f "$EXTEND_FILE"

    log "Starting graceful shutdown (${grace_seconds}s grace period)"
    log "To extend: touch $EXTEND_FILE (adds ${grace_seconds}s each time)"

    # Initial warning
    say_chat "[SERVER] Update available! Server will restart in ${remaining} seconds."
    say_chat "[SERVER] Please finish your current round."

    while [[ $remaining -gt 0 ]]; do
        sleep 1
        ((remaining--))

        # Check for extension request
        if [[ -f "$EXTEND_FILE" ]]; then
            rm -f "$EXTEND_FILE"
            remaining=$((remaining + grace_seconds))
            log "Grace period extended! Now ${remaining}s remaining"
            say_chat "[SERVER] Restart delayed! Now ${remaining} seconds until update."
        fi

        # Countdown warnings
        case $remaining in
            300) say_chat "[SERVER] Server restart in 5 minutes for update." ;;
            120) say_chat "[SERVER] Server restart in 2 minutes for update." ;;
            60)  say_chat "[SERVER] Server restart in 1 minute for update!" ;;
            30)  say_chat "[SERVER] Server restart in 30 seconds!" ;;
            10)  say_chat "[SERVER] Server restart in 10 seconds!" ;;
            5|4|3|2|1) say_chat "[SERVER] Restarting in ${remaining}..." ;;
        esac

        # Check if srcds still running
        if ! kill -0 "$SRCDS_PID" 2>/dev/null; then
            log "srcds no longer running during grace period"
            exit 0
        fi
    done

    say_chat "[SERVER] Restarting now for update. See you soon!"
    sleep 2
}

# ---------------------------------------------------------------------------
# Announce-only mode (no auto-restart)
# ---------------------------------------------------------------------------
announce_update() {
    warn "Update available! AUTO_UPDATE_MODE=announce — waiting for manual restart"
    say_chat "[SERVER] Game update available! Restart when convenient."
    say_chat "[SERVER] Admin: run 'docker compose restart' to apply update."

    # Don't check again for this session — just wait
    log "Waiting for manual intervention (or container restart)"
    while kill -0 "$SRCDS_PID" 2>/dev/null; do
        sleep 60
    done
    exit 0
}

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------
log "Started (checking every ${AUTO_UPDATE_INTERVAL}s, mode: ${AUTO_UPDATE_MODE})"

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
        case "${AUTO_UPDATE_MODE,,}" in
            graceful)
                graceful_shutdown
                warn "Grace period complete — stopping server for update"
                kill -TERM "$SRCDS_PID" 2>/dev/null || true
                exit 0
                ;;
            announce)
                announce_update
                # announce_update loops forever, so we won't reach here
                ;;
            immediate|*)
                warn "Stopping server for update — container will restart automatically..."
                kill -TERM "$SRCDS_PID" 2>/dev/null || true
                exit 0
                ;;
        esac
    fi
done
