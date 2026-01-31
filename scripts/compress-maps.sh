#!/usr/bin/env bash
# Compress BSP map files for FastDL.
# Clients download .bz2 first (faster), falling back to raw .bsp.
#
# Usage: ./scripts/compress-maps.sh [source_dir] [dest_dir]
# Default: data/maps/ → data/fastdl/tf2classified/maps/

set -euo pipefail

if ! command -v bzip2 &>/dev/null; then
    echo "Error: bzip2 is not installed"
    echo "Install with: sudo apt install bzip2"
    exit 1
fi

SOURCE_DIR="${1:-data/maps}"
DEST_DIR="${2:-data/fastdl/tf2classified/maps}"

mkdir -p "${DEST_DIR}"

shopt -s nullglob
BSP_FILES=("${SOURCE_DIR}"/*.bsp)
shopt -u nullglob

if [[ ${#BSP_FILES[@]} -eq 0 ]]; then
    echo "No .bsp files found in ${SOURCE_DIR}"
    exit 0
fi

echo "Compressing maps from ${SOURCE_DIR} → ${DEST_DIR}"
echo ""

COUNT=0
for bsp in "${BSP_FILES[@]}"; do
    filename="$(basename "${bsp}")"
    echo "  ${filename}"

    # Copy raw .bsp
    cp "${bsp}" "${DEST_DIR}/${filename}"

    # Compress if missing or source is newer
    if [[ ! -f "${DEST_DIR}/${filename}.bz2" ]] || [[ "${bsp}" -nt "${DEST_DIR}/${filename}.bz2" ]]; then
        bzip2 -kf "${DEST_DIR}/${filename}"

        ORIG_SIZE=$(stat -c%s "${DEST_DIR}/${filename}" 2>/dev/null || stat -f%z "${DEST_DIR}/${filename}")
        COMP_SIZE=$(stat -c%s "${DEST_DIR}/${filename}.bz2" 2>/dev/null || stat -f%z "${DEST_DIR}/${filename}.bz2")
        if command -v bc &>/dev/null; then
            RATIO=$(echo "scale=1; (1 - ${COMP_SIZE} / ${ORIG_SIZE}) * 100" | bc)
            echo "    → compressed ${RATIO}% smaller"
        else
            echo "    → compressed (${ORIG_SIZE} → ${COMP_SIZE} bytes)"
        fi
    else
        echo "    → already compressed (skipped)"
    fi

    ((COUNT++))
done

echo ""
echo "Done. ${COUNT} map(s) ready in ${DEST_DIR}"
echo ""
echo "Next steps:"
echo "  1. If using self-hosted FastDL: maps are already in place"
echo "  2. If using external FastDL (R2, S3, etc.): upload ${DEST_DIR}/ contents"
echo "  3. Set FASTDL_URL in .env and restart: docker compose restart"
