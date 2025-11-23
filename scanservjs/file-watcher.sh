#!/bin/bash
# File watcher for scanservjs output directory
# Uses inotify to monitor filesystem events in real-time

set -euo pipefail

OUTPUT_DIR="/app/data/output"
POST_SCAN_SCRIPT="/app/post-scan.sh"

# Check if inotifywait is available
if ! command -v inotifywait >/dev/null 2>&1; then
    echo "ERROR: inotifywait not found. Install inotify-tools package." >&2
    exit 1
fi

echo "Starting file watcher for: $OUTPUT_DIR"
echo "Monitoring for file creation and close events..."

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Use inotifywait to monitor filesystem events
# -m: monitor mode (run indefinitely)
# -r: recursive (watch subdirectories)
# --format: output format
# -e: events to watch (close_write = file written and closed, moved_to = file moved into directory)
inotifywait -m -r --format '%w%f' -e close_write,moved_to "$OUTPUT_DIR" | while read -r file; do
    # Only process regular files (not directories)
    if [[ -f "$file" ]]; then
        # Small delay to ensure file is fully written
        sleep 0.5
        
        # Verify file still exists and is readable
        if [[ -r "$file" ]]; then
            echo "New scan file detected: $file"
            # Run post-scan script
            "$POST_SCAN_SCRIPT" "$file" || {
                echo "WARNING: Post-scan script failed for: $file" >&2
            }
        fi
    fi
done

