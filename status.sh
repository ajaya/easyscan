#!/bin/bash
# Check status of scanner services

set -euo pipefail

# Safe environment variable loading
load_env() {
    if [ -f .env ]; then
        set -a
        while IFS= read -r line || [ -n "$line" ]; do
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
            export "$line"
        done < .env
        set +a
    fi
}

load_env

# Set defaults
SCANNER_BRAND=${SCANNER_BRAND:-epson}
SCANSERVJS_PORT=${SCANSERVJS_PORT:-8080}
AIRSANE_PORT=${AIRSANE_PORT:-8090}
SANED_PORT=${SANED_PORT:-6566}

echo "===================================="
echo "Scanner Service Status"
echo "===================================="
echo ""
echo "Container Status:"
echo "-------------------"
if ! docker-compose ps; then
    echo "WARNING: Could not get container status" >&2
fi
echo ""

echo "Scanner Detection:"
echo "-------------------"
echo -n "USB Detection:      "
if lsusb | grep -qi "$SCANNER_BRAND"; then
    echo "✓ $SCANNER_BRAND scanner found on USB"
else
    echo "✗ No $SCANNER_BRAND scanner on USB"
fi

echo -n "SANE Detection:     "
if docker ps --format '{{.Names}}' | grep -q "^saned$"; then
    if docker exec saned scanimage -L 2>/dev/null | grep -qi "$SCANNER_BRAND"; then
        echo "✓ Scanner found"
    else
        echo "✗ Scanner not found"
    fi
else
    echo "✗ Container not running"
fi

echo -n "AirSane Detection:  "
if docker ps --format '{{.Names}}' | grep -q "^airsane$"; then
    if docker exec airsane scanimage -L 2>/dev/null | grep -qi "$SCANNER_BRAND"; then
        echo "✓ Scanner found"
    else
        echo "✗ Scanner not found"
    fi
else
    echo "✗ Container not running"
fi

echo -n "ScanServJS:         "
if docker ps --format '{{.Names}}' | grep -q "^scanservjs$"; then
    if docker exec scanservjs scanimage -L 2>/dev/null | grep -qi "$SCANNER_BRAND"; then
        echo "✓ Scanner found"
    else
        echo "✗ Scanner not found"
    fi
else
    echo "✗ Container not running"
fi

echo ""
echo "Network Endpoints:"
echo "-------------------"
# Get IP address with fallbacks
get_ip_address() {
    local ip
    if command -v hostname >/dev/null 2>&1 && ip=$(hostname -I 2>/dev/null | awk '{print $1}') && [[ -n "$ip" ]]; then
        echo "$ip"
    elif command -v ip >/dev/null 2>&1 && ip=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+' || true) && [[ -n "$ip" ]]; then
        echo "$ip"
    elif command -v hostname >/dev/null 2>&1 && ip=$(hostname -i 2>/dev/null) && [[ -n "$ip" ]]; then
        echo "$ip"
    else
        echo "localhost"
    fi
}

IP_ADDR=$(get_ip_address)
echo "Web Interface:      http://${IP_ADDR}:${SCANSERVJS_PORT}"
echo "AirScan/eSCL:       http://${IP_ADDR}:${AIRSANE_PORT}"
echo "SANE Network:       ${IP_ADDR}:${SANED_PORT}"
echo ""
echo "Allowed Networks:   ${ALLOWED_NETWORK:-not set}, ${SECONDARY_NETWORK:-not set}"
