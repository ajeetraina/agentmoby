#!/bin/bash
# security-monitor.sh - MCP Gateway Security Interceptor (Before Hook)
# Simplified for local testing

set -euo pipefail

LOG_FILE="/tmp/sessions/security.log"
SESSION_DIR="/tmp/sessions"

# Ensure directories exist
mkdir -p "$SESSION_DIR"
touch "$LOG_FILE"

# Simple logging function
log_event() {
    local level="$1"
    local message="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "[$timestamp] [$level] SECURITY: $message" >> "$LOG_FILE"
    echo "[$timestamp] [$level] SECURITY: $message" >&2
}

# Read payload
payload=$(cat)

# Extract tool name for logging
tool_name=$(echo "$payload" | jq -r '.method // "unknown"' 2>/dev/null || echo "unknown")

# Basic security checks for local testing
if echo "$payload" | grep -qiE "(ignore.*previous|forget.*instructions|system.*override)"; then
    log_event "WARNING" "Potential prompt injection detected for tool: $tool_name"
    echo "SECURITY_WARNING: Potential security issue detected but allowing for local testing"
fi

if echo "$payload" | grep -qiE "(password|secret|key.*[:=])"; then
    log_event "INFO" "Potential secret detected for tool: $tool_name"
fi

# Log and forward
log_event "INFO" "Tool call processed: $tool_name"
echo "$payload"
