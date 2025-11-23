#!/bin/bash
# Start scanner services

set -euo pipefail

# Parse command line arguments
SKIP_SCANNER_CHECK=false
FORCE=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-check|--force)
            SKIP_SCANNER_CHECK=true
            FORCE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--skip-check|--force]"
            echo ""
            echo "Options:"
            echo "  --skip-check, --force  Skip USB scanner detection check"
            echo "  --help, -h            Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Use --help for usage information" >&2
            exit 1
            ;;
    esac
done

# Safe environment variable loading
load_env() {
    if [ -f .env ]; then
        set -a
        # Use a safer method that handles spaces and special characters
        while IFS= read -r line || [ -n "$line" ]; do
            # Skip empty lines and comments
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
            # Export the variable
            export "$line"
        done < .env
        set +a
    fi
}

load_env

# Set defaults for optional variables
SANE_DEBUG_LEVEL=${SANE_DEBUG_LEVEL:-1}
SCANNER_BRAND=${SCANNER_BRAND:-epson}

# Validate required environment variables
required_vars=("ALLOWED_NETWORK" "SCANSERVJS_PORT" "AIRSANE_PORT" "SANED_PORT")
missing_vars=()
for var in "${required_vars[@]}"; do
    if [[ -z "${!var:-}" ]]; then
        missing_vars+=("$var")
    fi
done

if [[ ${#missing_vars[@]} -gt 0 ]]; then
    echo "ERROR: Required environment variables are not set:" >&2
    printf '  - %s\n' "${missing_vars[@]}" >&2
    echo "" >&2
    echo "Please edit .env file and set the required variables." >&2
    exit 1
fi

echo "==================================="
echo "SCAN Server Startup"
echo "==================================="
echo "Allowed Network: ${ALLOWED_NETWORK}"
echo "Secondary Network: ${SECONDARY_NETWORK:-none}"
echo ""

# Check for scanner (unless skipped)
if [[ "$SKIP_SCANNER_CHECK" == false ]]; then
    echo "Checking for scanner..."
    if ! lsusb | grep -qi "$SCANNER_BRAND"; then
        echo "WARNING: No $SCANNER_BRAND scanner detected on USB!"
        echo "Please connect your scanner and try again."
        
        # Only prompt if running interactively
        if [[ -t 0 ]]; then
            read -p "Continue anyway? (y/n) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        else
            echo "ERROR: Scanner not detected and not running interactively." >&2
            echo "Use --skip-check to bypass this check." >&2
            exit 1
        fi
    fi
fi

echo "Building custom saned image if needed..."
if ! docker-compose build; then
    echo "ERROR: Build failed" >&2
    exit 1
fi

echo "Starting scanner services..."
if ! docker-compose up -d; then
    echo "ERROR: Failed to start services" >&2
    exit 1
fi

echo "Waiting for services to start..."
sleep 10

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

echo ""
echo "Scanner services are running!"
echo "==================================="
echo "Web Interface:     http://${IP_ADDR}:${SCANSERVJS_PORT}"
echo "AirScan/eSCL:      http://${IP_ADDR}:${AIRSANE_PORT}" 
echo "SANE Network:      ${IP_ADDR}:${SANED_PORT}"
echo "==================================="
echo ""
echo "View logs: docker-compose logs -f"
echo "Check status: ./status.sh"
