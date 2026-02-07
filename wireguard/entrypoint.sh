#!/bin/sh
set -e

# ── Validate required env vars ────────────────────────────────────────────
for var in WG_PRIVATE_KEY WG_PEER_PUBLIC_KEY WG_ENDPOINT; do
    eval val="\$$var"
    if [ -z "$val" ]; then
        echo "ERROR: ${var} is not set. Check your .env file."
        exit 1
    fi
done

WG_ADDRESS="${WG_ADDRESS:-10.0.0.2/24}"
WG_DNS="${WG_DNS:-1.1.1.1}"
WG_ALLOWED_IPS="${WG_ALLOWED_IPS:-0.0.0.0/0}"
WG_PERSISTENT_KEEPALIVE="${WG_PERSISTENT_KEEPALIVE:-25}"
WG_RERESOLVE_INTERVAL="${WG_RERESOLVE_INTERVAL:-300}"

# ── Generate wg0.conf from env vars ──────────────────────────────────────
# Table = off prevents wg-quick from using fwmark routing (which needs
# the src_valid_mark sysctl that Docker blocks). We set up routing manually.
cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
PrivateKey = ${WG_PRIVATE_KEY}
Address = ${WG_ADDRESS}
Table = off

[Peer]
PublicKey = ${WG_PEER_PUBLIC_KEY}
Endpoint = ${WG_ENDPOINT}
AllowedIPs = ${WG_ALLOWED_IPS}
PersistentKeepalive = ${WG_PERSISTENT_KEEPALIVE}
EOF

chmod 600 /etc/wireguard/wg0.conf
echo "Generated wg0.conf (endpoint: ${WG_ENDPOINT})"

# ── Start WireGuard ──────────────────────────────────────────────────────
wg-quick up wg0

# Set up routing manually since Table = off skips wg-quick's route setup.
# Get the WireGuard endpoint IP so we can keep that routed via the default gateway.
ENDPOINT_HOST=$(echo "${WG_ENDPOINT}" | cut -d: -f1)
ENDPOINT_PORT=$(echo "${WG_ENDPOINT}" | cut -d: -f2)

# Resolve endpoint to IP
ENDPOINT_IP=$(getent hosts "${ENDPOINT_HOST}" 2>/dev/null | awk '{print $1; exit}')
if [ -z "${ENDPOINT_IP}" ]; then
    # Maybe it's already an IP
    ENDPOINT_IP="${ENDPOINT_HOST}"
fi

# Save current default gateway before we replace it
DEFAULT_GW=$(ip route show default | awk '{print $3; exit}')
DEFAULT_DEV=$(ip route show default | awk '{print $5; exit}')

if [ -n "${DEFAULT_GW}" ] && [ -n "${DEFAULT_DEV}" ]; then
    # Keep endpoint reachable via the original gateway
    ip route add "${ENDPOINT_IP}/32" via "${DEFAULT_GW}" dev "${DEFAULT_DEV}" 2>/dev/null || true
    # Route everything else through WireGuard
    ip route replace default dev wg0
    echo "Routing: default via wg0, endpoint ${ENDPOINT_IP} via ${DEFAULT_DEV}"
else
    echo "WARNING: No default gateway found, setting wg0 as default"
    ip route add default dev wg0 2>/dev/null || true
fi

# Set DNS
echo "nameserver ${WG_DNS}" > /etc/resolv.conf

echo "WireGuard tunnel up (${WG_ADDRESS})"

# ── DDNS re-resolve loop ─────────────────────────────────────────────────
# WireGuard only resolves the endpoint hostname once. If the remote IP
# changes (dynamic IP / DDNS), we re-resolve periodically and update
# both the WireGuard peer endpoint and the host route.
case "${ENDPOINT_HOST}" in
    *[a-zA-Z]*)
        (
            while sleep "${WG_RERESOLVE_INTERVAL}"; do
                new_ip=$(getent hosts "${ENDPOINT_HOST}" 2>/dev/null | awk '{print $1; exit}')
                [ -z "${new_ip}" ] && continue

                current=$(wg show wg0 endpoints 2>/dev/null \
                    | grep "${WG_PEER_PUBLIC_KEY}" \
                    | awk '{print $2}' | cut -d: -f1)

                if [ "${new_ip}" != "${current}" ]; then
                    # Update WireGuard peer endpoint
                    wg set wg0 peer "${WG_PEER_PUBLIC_KEY}" \
                        endpoint "${new_ip}:${ENDPOINT_PORT}"
                    # Update host route for new endpoint IP
                    if [ -n "${DEFAULT_GW}" ] && [ -n "${DEFAULT_DEV}" ]; then
                        ip route del "${current}/32" via "${DEFAULT_GW}" 2>/dev/null || true
                        ip route add "${new_ip}/32" via "${DEFAULT_GW}" dev "${DEFAULT_DEV}" 2>/dev/null || true
                    fi
                    echo "$(date): Endpoint updated ${current} -> ${new_ip}"
                fi
            done
        ) &
        RERESOLVE_PID=$!
        echo "DDNS re-resolve running (every ${WG_RERESOLVE_INTERVAL}s, PID ${RERESOLVE_PID})"
        ;;
    *)
        echo "Static IP endpoint, skipping DDNS re-resolve"
        ;;
esac

# ── Wait for shutdown signal ─────────────────────────────────────────────
cleanup() {
    echo "Shutting down WireGuard..."
    [ -n "${RERESOLVE_PID}" ] && kill "${RERESOLVE_PID}" 2>/dev/null
    wg-quick down wg0
    exit 0
}
trap cleanup SIGTERM SIGINT

# Sleep forever, waiting for signal
while true; do sleep 60 & wait $!; done
