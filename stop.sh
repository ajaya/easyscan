#!/bin/bash
# Stop scanner services

set -euo pipefail

echo "Stopping scanner services gracefully..."
# Give containers 30 seconds to finish any active scans
if ! docker-compose stop -t 30; then
    echo "WARNING: Some services may not have stopped gracefully" >&2
fi

echo "Removing containers..."
if ! docker-compose down; then
    echo "ERROR: Failed to remove containers" >&2
    exit 1
fi

echo "Services stopped."
