#!/usr/bin/env bash
# Update game files and re-apply symlinks.
# Run inside the container:  docker compose exec tf2classified /opt/scripts/update.sh
set -euo pipefail

: "${STEAMCMD_DIR:=/opt/steamcmd}"
: "${TF2_DIR:=/data/tf}"
: "${CLASSIFIED_DIR:=/data/classified}"

GREEN='\033[0;32m'
NC='\033[0m'
log() { echo -e "${GREEN}[UPDATE]${NC} $1"; }

log "Updating TF2 base (AppID 232250)..."
"${STEAMCMD_DIR}/steamcmd.sh" \
    +force_install_dir "${TF2_DIR}" \
    +login anonymous \
    +app_update 232250 \
    +quit

log "Updating TF2 Classified (AppID 3557020)..."
"${STEAMCMD_DIR}/steamcmd.sh" \
    +force_install_dir "${CLASSIFIED_DIR}" \
    +login anonymous \
    +app_update 3557020 \
    +quit

log "Re-applying library symlinks..."

(cd "${CLASSIFIED_DIR}/bin/linux64" && rm -f libvstdlib.so && ln -sf libvstdlib_srv.so libvstdlib.so)
(cd "${CLASSIFIED_DIR}/tf2classified/bin/linux64" && ln -sf server.so server_srv.so)

mkdir -p /home/srcds/.steam/sdk64
ln -sf "${CLASSIFIED_DIR}/linux64/steamclient.so" /home/srcds/.steam/sdk64/steamclient.so

log "Done. Restart the container to pick up changes."
