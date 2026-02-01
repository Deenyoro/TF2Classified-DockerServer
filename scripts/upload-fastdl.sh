#!/usr/bin/env bash
# upload-fastdl.sh — Compress maps and upload to Cloudflare R2
#
# Workflow:
#   1. Copies .bsp files from data/maps/ to data/fastdl/tf2classified/maps/
#   2. bzip2-compresses them (clients download .bz2 first, faster)
#   3. Uploads the entire data/fastdl/ tree to the R2 bucket
#
# Required env vars (set in .env or export before running):
#   R2_ENDPOINT      — Your R2 S3 API endpoint
#   R2_BUCKET        — Bucket name
#   R2_PUBLIC_URL    — Public bucket URL (for the "done" message)
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

# Source .env if it exists (pick up R2_* vars)
if [[ -f "${PROJECT_DIR}/.env" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "${PROJECT_DIR}/.env"
    set +a
fi

# R2 configuration from env
R2_ENDPOINT="${R2_ENDPOINT:-}"
R2_BUCKET="${R2_BUCKET:-}"
R2_PUBLIC_URL="${R2_PUBLIC_URL:-}"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
log()  { echo -e "${GREEN}[UPLOAD]${NC} $1"; }
step() { echo -e "${CYAN}[STEP]${NC}  $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $1"; }
err()  { echo -e "${RED}[ERROR]${NC} $1"; }

# --- Checks ---
if [[ -z "${R2_ENDPOINT}" ]]; then
    err "R2_ENDPOINT not set. Add it to .env or export it."
    err "Example: R2_ENDPOINT=https://<account-id>.r2.cloudflarestorage.com"
    exit 1
fi

if [[ -z "${R2_BUCKET}" ]]; then
    err "R2_BUCKET not set. Add it to .env or export it."
    err "Example: R2_BUCKET=my-fastdl-bucket"
    exit 1
fi

if [[ ! -f "${CREDS_FILE}" ]]; then
    err "R2 credentials not found at ${CREDS_FILE}"
    echo "Create .r2/credentials with your Access Key ID and Secret Access Key."
    exit 1
fi

if ! command -v aws &>/dev/null; then
    err "aws CLI not installed"
    echo "Install with: apt install awscli  or  pip install awscli"
    exit 1
fi

if ! command -v bzip2 &>/dev/null; then
    err "bzip2 not installed"
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
if [[ -n "${R2_PUBLIC_URL}" ]]; then
    log "Done! Files are live at:"
    log "  ${R2_PUBLIC_URL}"
else
    log "Done! Upload complete."
    log "Set R2_PUBLIC_URL in .env to see the public link here."
fi
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
