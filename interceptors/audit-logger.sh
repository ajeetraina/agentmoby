#!/bin/bash
# audit-logger.sh - MCP Gateway Audit Logger (After Hook)
# Simplified for local testing

set -euo pipefail

AUDIT_LOG="/tmp/sessions/audit.log"
mkdir -p "$(dirname "$AUDIT_LOG")"
touch "$AUDIT_LOG"

# Read response
response=$(cat)

# Simple audit logging
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
echo "[$timestamp] AUDIT: Response logged (${#response} bytes)" >> "$AUDIT_LOG"

# Check for potential sensitive data (basic patterns)
if echo "$response" | grep -qE "(sk-[a-zA-Z0-9]{48}|ghp_[a-zA-Z0-9]{36})"; then
    echo "[$timestamp] AUDIT: Potential sensitive data detected in response" >> "$AUDIT_LOG"
fi

# Forward response
echo "$response"
