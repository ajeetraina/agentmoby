#!/bin/bash

# MobyAgent Rate Limiter Interceptor
# Prevents DoS attacks and ensures fair resource usage
# Uses Redis for distributed rate limiting

set -euo pipefail

# Configuration
REDIS_URL="${REDIS_URL:-redis://redis:6379}"
REDIS_PASSWORD="${REDIS_PASSWORD:-mobyagent}"
GLOBAL_LIMIT="${GLOBAL_LIMIT:-1000}"
PER_USER_LIMIT="${PER_USER_LIMIT:-100}"
PER_IP_LIMIT="${PER_IP_LIMIT:-50}"
WINDOW_SECONDS="${WINDOW_SECONDS:-3600}"
BLOCK_DURATION="${BLOCK_DURATION:-300}"

# Logging function
log_message() {
    echo "$(date -Iseconds) [RATE_LIMITER] $1" >&2
}

# Redis connection function
redis_cmd() {
    redis-cli -u "$REDIS_URL" -a "$REDIS_PASSWORD" --no-auth-warning "$@"
}

# Extract client information from request
extract_client_info() {
    local request_json="$1"
    
    # Extract IP address
    local client_ip
    client_ip=$(echo "$request_json" | jq -r '.client.ip // "unknown"')
    
    # Extract user ID
    local user_id
    user_id=$(echo "$request_json" | jq -r '.auth.user_id // "anonymous"')
    
    # Extract API key hash for identification
    local api_key_hash
    api_key_hash=$(echo "$request_json" | jq -r '.auth.api_key_hash // "none"')
    
    echo "${client_ip}|${user_id}|${api_key_hash}"
}

# Check rate limits using sliding window
check_rate_limit() {
    local key="$1"
    local limit="$2"
    local window="$3"
    local current_time
    current_time=$(date +%s)
    local window_start=$((current_time - window))
    
    # Remove old entries
    redis_cmd ZREMRANGEBYSCORE "$key" 0 "$window_start" > /dev/null
    
    # Count current requests in window
    local current_count
    current_count=$(redis_cmd ZCARD "$key")
    
    if [ "$current_count" -ge "$limit" ]; then
        return 1  # Rate limit exceeded
    fi
    
    # Add current request
    redis_cmd ZADD "$key" "$current_time" "${current_time}_$(uuidgen)" > /dev/null
    redis_cmd EXPIRE "$key" $((window + 60)) > /dev/null  # Set expiry with buffer
    
    return 0  # Within rate limit
}

# Check if client is in block list
is_blocked() {
    local client_key="$1"
    local block_key="blocked:${client_key}"
    local is_blocked
    is_blocked=$(redis_cmd EXISTS "$block_key")
    [ "$is_blocked" -eq 1 ]
}

# Block a client
block_client() {
    local client_key="$1"
    local reason="$2"
    local block_key="blocked:${client_key}"
    
    redis_cmd SETEX "$block_key" "$BLOCK_DURATION" "$reason" > /dev/null
    log_message "BLOCKED client $client_key for $BLOCK_DURATION seconds. Reason: $reason"
}

# Get rate limit status
get_rate_limit_status() {
    local key="$1"
    local limit="$2"
    local window="$3"
    local current_time
    current_time=$(date +%s)
    local window_start=$((current_time - window))
    
    # Clean old entries
    redis_cmd ZREMRANGEBYSCORE "$key" 0 "$window_start" > /dev/null
    
    # Get current count
    local current_count
    current_count=$(redis_cmd ZCARD "$key")
    
    local remaining=$((limit - current_count))
    [ $remaining -lt 0 ] && remaining=0
    
    echo "{\"limit\": $limit, \"remaining\": $remaining, \"reset_time\": $((current_time + window))}"
}

# Main rate limiting logic
main() {
    local request_json="$1"
    
    if [ -z "$request_json" ]; then
        log_message "ERROR: No request data provided"
        echo '{"action": "block", "reason": "no_request_data"}'
        exit 1
    fi
    
    # Extract client information
    local client_info
    client_info=$(extract_client_info "$request_json")
    IFS='|' read -r client_ip user_id api_key_hash <<< "$client_info"
    
    log_message "Processing request from IP: $client_ip, User: $user_id"
    
    # Check if client is blocked
    if is_blocked "$client_ip"; then
        local block_reason
        block_reason=$(redis_cmd GET "blocked:${client_ip}")
        log_message "BLOCKED request from $client_ip - Reason: $block_reason"
        echo "{\"action\": \"block\", \"reason\": \"client_blocked\", \"block_reason\": \"$block_reason\"}"
        exit 1
    fi
    
    if is_blocked "$user_id"; then
        local block_reason
        block_reason=$(redis_cmd GET "blocked:${user_id}")
        log_message "BLOCKED request from user $user_id - Reason: $block_reason"
        echo "{\"action\": \"block\", \"reason\": \"user_blocked\", \"block_reason\": \"$block_reason\"}"
        exit 1
    fi
    
    # Define rate limit keys
    local global_key="rate_limit:global"
    local ip_key="rate_limit:ip:${client_ip}"
    local user_key="rate_limit:user:${user_id}"
    
    # Check global rate limit
    if ! check_rate_limit "$global_key" "$GLOBAL_LIMIT" "$WINDOW_SECONDS"; then
        log_message "GLOBAL RATE LIMIT EXCEEDED - blocking all requests temporarily"
        # Block the entire system temporarily
        redis_cmd SETEX "blocked:global" "$((BLOCK_DURATION / 2))" "global_rate_limit_exceeded" > /dev/null
        echo '{"action": "block", "reason": "global_rate_limit_exceeded", "retry_after": '$((BLOCK_DURATION / 2))'}'
        exit 1
    fi
    
    # Check per-IP rate limit
    if ! check_rate_limit "$ip_key" "$PER_IP_LIMIT" "$WINDOW_SECONDS"; then
        block_client "$client_ip" "ip_rate_limit_exceeded"
        local ip_status
        ip_status=$(get_rate_limit_status "$ip_key" "$PER_IP_LIMIT" "$WINDOW_SECONDS")
        echo "{\"action\": \"block\", \"reason\": \"ip_rate_limit_exceeded\", \"retry_after\": $BLOCK_DURATION, \"rate_limit_status\": $ip_status}"
        exit 1
    fi
    
    # Check per-user rate limit
    if [ "$user_id" != "anonymous" ]; then
        if ! check_rate_limit "$user_key" "$PER_USER_LIMIT" "$WINDOW_SECONDS"; then
            block_client "$user_id" "user_rate_limit_exceeded"
            local user_status
            user_status=$(get_rate_limit_status "$user_key" "$PER_USER_LIMIT" "$WINDOW_SECONDS")
            echo "{\"action\": \"block\", \"reason\": \"user_rate_limit_exceeded\", \"retry_after\": $BLOCK_DURATION, \"rate_limit_status\": $user_status}"
            exit 1
        fi
    fi
    
    # Get rate limit status for headers
    local global_status
    global_status=$(get_rate_limit_status "$global_key" "$GLOBAL_LIMIT" "$WINDOW_SECONDS")
    local ip_status
    ip_status=$(get_rate_limit_status "$ip_key" "$PER_IP_LIMIT" "$WINDOW_SECONDS")
    local user_status="{}"
    if [ "$user_id" != "anonymous" ]; then
        user_status=$(get_rate_limit_status "$user_key" "$PER_USER_LIMIT" "$WINDOW_SECONDS")
    fi
    
    log_message "Rate limit check passed for $client_ip / $user_id"
    
    # Return success with rate limit information
    echo "{
        \"action\": \"allow\",
        \"reason\": \"rate_limit_passed\",
        \"rate_limits\": {
            \"global\": $global_status,
            \"ip\": $ip_status,
            \"user\": $user_status
        }
    }"
    
    exit 0
}

# Check if Redis is available
if ! redis_cmd PING > /dev/null 2>&1; then
    log_message "ERROR: Cannot connect to Redis at $REDIS_URL"
    echo '{"action": "block", "reason": "redis_unavailable"}'
    exit 1
fi

# Run main logic
main "$1"
