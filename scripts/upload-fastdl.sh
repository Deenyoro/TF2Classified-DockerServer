#!/usr/bin/env bash
# upload-fastdl.sh — Compress maps and upload to Cloudflare R2
#
# Workflow:
#   1. Copies .bsp files from data/maps/ to data/fastdl/tf2classified/maps/
#   2. bzip2-compresses them (clients download .bz2 first, faster)
#   3. Uploads the entire data/fastdl/ tree to the R2 bucket
#
# Usage: ./scripts/upload-fastdl.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
CREDS_FILE="${PROJECT_DIR}/.r2/credentials"
CONFIG_FILE="${PROJECT_DIR}/.r2/config"
FASTDL_DIR="${PROJECT_DIR}/data/fastdl"
MAPS_SRC="${PROJECT_DIR}/data/maps"
MAPS_DEST="${FASTDL_DIR}/tf2classified/maps"

# R2 configuration

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'
log()  { echo -e "${GREEN}[UPLOAD]${NC} $1"; }
step() { echo -e "${CYAN}[STEP]${NC}  $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $1"; }

# --- Checks ---
if [[ ! -f "${CREDS_FILE}" ]]; then
    echo "Error: R2 credentials not found at ${CREDS_FILE}"
    echo "Create .r2/credentials with your Access Key ID and Secret Access Key."
    exit 1
fi

if ! command -v aws &>/dev/null; then
    echo "Error: aws CLI not installed"
    echo "Install with: apt install awscli  or  pip install awscli"
    exit 1
fi

if ! command -v bzip2 &>/dev/null; then
    echo "Error: bzip2 not installed"
    exit 1
fi

# --- Step 1: Compress maps ---
mkdir -p "${MAPS_DEST}"

shopt -s nullglob
BSP_FILES=("${MAPS_SRC}"/*.bsp)
shopt -u nullglob

if [[ ${#BSP_FILES[@]} -eq 0 ]]; then
    warn "No .bsp files in ${MAPS_SRC} — uploading existing fastdl content only"
else
    step "Compressing ${#BSP_FILES[@]} map(s)..."
    for bsp in "${BSP_FILES[@]}"; do
        filename="$(basename "${bsp}")"
        cp "${bsp}" "${MAPS_DEST}/${filename}"
        if [[ ! -f "${MAPS_DEST}/${filename}.bz2" ]] || [[ "${bsp}" -nt "${MAPS_DEST}/${filename}.bz2" ]]; then
            bzip2 -kf "${MAPS_DEST}/${filename}"
            log "  ${filename} → compressed"
        else
            log "  ${filename} → already compressed"
        fi
    done
fi

# --- Step 2: Upload to R2 ---
step "Uploading to R2 (${R2_BUCKET})..."

AWS_SHARED_CREDENTIALS_FILE="${CREDS_FILE}" \
AWS_CONFIG_FILE="${CONFIG_FILE}" \
aws s3 sync "${FASTDL_DIR}/" "s3://${R2_BUCKET}/" \
    --endpoint-url "${R2_ENDPOINT}" \
    --region auto \
    --delete \
    --size-only \
    2>&1

echo ""
log "Done! Files are live at:"
echo ""

# --- Step 3: List what's in the bucket ---
step "Bucket contents:"
AWS_SHARED_CREDENTIALS_FILE="${CREDS_FILE}" \
AWS_CONFIG_FILE="${CONFIG_FILE}" \
aws s3 ls "s3://${R2_BUCKET}/" \
    --endpoint-url "${R2_ENDPOINT}" \
    --region auto \
    --recursive \
    2>&1

echo ""
