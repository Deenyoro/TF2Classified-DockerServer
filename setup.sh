#!/usr/bin/env bash
set -euo pipefail

echo ""
echo "============================================"
echo "  TF2 Classified Docker Server Setup"
echo "============================================"
echo ""

# --- Prerequisites ---
if ! command -v docker &>/dev/null; then
    echo "ERROR: Docker is not installed."
    echo "       https://docs.docker.com/get-docker/"
    exit 1
fi

if ! docker compose version &>/dev/null; then
    echo "ERROR: Docker Compose v2 not available."
    echo "       https://docs.docker.com/compose/install/"
    exit 1
fi

echo "[OK] Docker and Docker Compose found"

# --- Data directories ---
echo "[..] Creating data directories..."
mkdir -p data/{cfg,addons,maps,logs,demos}
mkdir -p data/addons/sourcemod/{plugins,configs}
mkdir -p data/fastdl/tf2classified/{maps,materials,models,sound}

# --- .env ---
if [[ ! -f .env ]]; then
    cp .env.example .env

    # Generate a random alphanumeric RCON password
    RCON_PASS=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 20)
    sed -i "s/^RCON_PASSWORD=changeme$/RCON_PASSWORD=${RCON_PASS}/" .env

    echo "[OK] Created .env"
    echo "     RCON password: ${RCON_PASS}"
    echo "     Write this down. You need it for remote admin."
else
    echo "[--] .env already exists, not overwriting"
fi

# --- Default custom config ---
if [[ ! -f data/cfg/server_custom.cfg ]]; then
    cat > data/cfg/server_custom.cfg << 'EOF'
// Custom server settings — loaded after server.cfg
// This file survives container restarts. Put your overrides here.

// mp_timelimit 20
// mp_winlimit 3
// sv_alltalk 1
EOF
    echo "[OK] Created data/cfg/server_custom.cfg"
fi

echo ""
echo "============================================"
echo "  Done."
echo "============================================"
echo ""
echo "Next:"
echo ""
echo "  1. Edit your config:         nano .env"
echo "  2. Build and start:          docker compose up -d"
echo "  3. Watch first-run install:  docker compose logs -f"
echo "     (downloads ~20GB of game files on first boot)"
echo ""
echo "Optional — FastDL (custom map downloads):"
echo "  Drop .bsp files in data/maps/, then:  make compress-maps"
echo "  Set FASTDL_URL in .env"
echo "  Self-hosted:  docker compose --profile fastdl up -d"
echo "  External (R2, S3, etc.): upload data/fastdl/ contents"
echo ""
