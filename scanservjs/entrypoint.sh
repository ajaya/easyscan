#!/bin/bash
# Custom entrypoint for scanservjs that also runs file watcher

set -euo pipefail

# Start file watcher in background if post-scan features are enabled
if [[ "${SMB_ENABLED:-false}" == "true" ]] || [[ "${EMAIL_ENABLED:-false}" == "true" ]]; then
    echo "Starting file watcher for post-scan processing..."
    /app/file-watcher.sh &
fi

# Start scanservjs using the original entrypoint script if it exists
if [[ -f /app/entrypoint-original.sh ]]; then
    exec /app/entrypoint-original.sh "$@"
elif [[ -f /entrypoint.sh ]]; then
    exec /entrypoint.sh "$@"
else
    # Fallback: start node server directly
    cd /app && exec node ./server/server.js "$@"
fi

