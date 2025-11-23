#!/bin/bash
# Post-scan script for scanservjs
# Orchestrates copying scanned files to SMB share and/or sending via email

set -euo pipefail

# Get the scanned file path
SCAN_FILE="${1:-}"
if [[ -z "$SCAN_FILE" ]]; then
    echo "ERROR: No scan file provided" >&2
    exit 1
fi

if [[ ! -f "$SCAN_FILE" ]]; then
    echo "ERROR: Scan file does not exist: $SCAN_FILE" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SMB_HANDLER="${SCRIPT_DIR}/smb-handler.sh"
EMAIL_HANDLER="${SCRIPT_DIR}/email-handler.sh"

echo "Processing post-scan actions for: $SCAN_FILE"

# Process SMB copy if handler exists
if [[ -f "$SMB_HANDLER" ]] && [[ -x "$SMB_HANDLER" ]]; then
    "$SMB_HANDLER" "$SCAN_FILE" || {
        echo "WARNING: SMB handler failed" >&2
    }
else
    echo "WARNING: SMB handler not found or not executable: $SMB_HANDLER" >&2
fi

# Process email sending if handler exists
if [[ -f "$EMAIL_HANDLER" ]] && [[ -x "$EMAIL_HANDLER" ]]; then
    "$EMAIL_HANDLER" "$SCAN_FILE" || {
        echo "WARNING: Email handler failed" >&2
    }
else
    echo "WARNING: Email handler not found or not executable: $EMAIL_HANDLER" >&2
fi

exit 0

