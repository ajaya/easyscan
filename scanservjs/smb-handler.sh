#!/bin/bash
# SMB/CIFS network share handler
# Handles mounting and copying files to SMB shares

set -euo pipefail

SCAN_FILE="${1:-}"
if [[ -z "$SCAN_FILE" ]]; then
    echo "ERROR: No scan file provided" >&2
    exit 1
fi

if [[ ! -f "$SCAN_FILE" ]]; then
    echo "ERROR: Scan file does not exist: $SCAN_FILE" >&2
    exit 1
fi

# Load environment variables
if [[ -f /.env ]]; then
    set -a
    source /.env
    set +a
fi

# Check if SMB is enabled
if [[ "${SMB_ENABLED:-false}" != "true" ]] || [[ -z "${SMB_SERVER:-}" ]]; then
    exit 0
fi

SMB_MOUNT_POINT="/mnt/smb"
SMB_SHARE="${SMB_SHARE:-}"
SMB_USER="${SMB_USER:-}"
SMB_PASS="${SMB_PASS:-}"
SMB_DOMAIN="${SMB_DOMAIN:-}"

if [[ -z "$SMB_SHARE" ]]; then
    echo "WARNING: SMB_SHARE not configured" >&2
    exit 1
fi

echo "Processing SMB copy: ${SMB_SERVER}/${SMB_SHARE}"

# Ensure mount point exists
mkdir -p "$SMB_MOUNT_POINT"

# Build mount options
MOUNT_OPTS="username=${SMB_USER},password=${SMB_PASS}"
if [[ -n "$SMB_DOMAIN" ]]; then
    MOUNT_OPTS="${MOUNT_OPTS},domain=${SMB_DOMAIN}"
fi
MOUNT_OPTS="${MOUNT_OPTS},uid=${PUID:-1000},gid=${PGID:-1000},file_mode=0664,dir_mode=0775"

# Check if mount point is already mounted
if mountpoint -q "$SMB_MOUNT_POINT" 2>/dev/null; then
    # Mount exists - test if it's still working by trying to list directory
    if ! ls "$SMB_MOUNT_POINT" >/dev/null 2>&1; then
        # Mount is stale - unmount and remount
        echo "Detected stale SMB mount, remounting..."
        umount "$SMB_MOUNT_POINT" 2>/dev/null || true
        mount -t cifs "//${SMB_SERVER}/${SMB_SHARE}" "$SMB_MOUNT_POINT" -o "$MOUNT_OPTS" || {
            echo "WARNING: Failed to remount SMB share" >&2
            exit 1
        }
    fi
else
    # Not mounted - mount it
    echo "Mounting SMB share: ${SMB_SERVER}/${SMB_SHARE}"
    mount -t cifs "//${SMB_SERVER}/${SMB_SHARE}" "$SMB_MOUNT_POINT" -o "$MOUNT_OPTS" || {
        echo "WARNING: Failed to mount SMB share" >&2
        exit 1
    }
fi

# Copy file to SMB share (only if mount is working)
if mountpoint -q "$SMB_MOUNT_POINT" 2>/dev/null; then
    FILENAME=$(basename "$SCAN_FILE")
    if cp "$SCAN_FILE" "${SMB_MOUNT_POINT}/${FILENAME}" 2>/dev/null; then
        echo "Successfully copied to SMB share: ${SMB_MOUNT_POINT}/${FILENAME}"
        exit 0
    else
        echo "WARNING: Failed to copy to SMB share (mount may be stale)" >&2
        # Try to remount on next scan by unmounting
        umount "$SMB_MOUNT_POINT" 2>/dev/null || true
        exit 1
    fi
else
    echo "WARNING: SMB mount point is not mounted" >&2
    exit 1
fi

