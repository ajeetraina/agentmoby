#!/bin/bash
# secrets-filter.sh - Secrets Filter (Before Hook)
# Simplified for local testing

set -euo pipefail

LOG_FILE="/tmp/sessions/secrets.log"
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

# Read payload
payload=$(cat)

# Simple secret detection and logging
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

if echo "$payload" | grep -qE "(sk-[a-zA-Z0-9]{48}|ghp_[a-zA-Z0-9]{36})"; then
    echo "[$timestamp] SECRETS: Potential secret detected in request" >> "$LOG_FILE"
    # In production, this would sanitize. For local testing, just log.
fi

echo "[$timestamp] SECRETS: Request processed" >> "$LOG_FILE"
echo "$payload"
