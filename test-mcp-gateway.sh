#!/bin/bash
echo "🧪 Testing MCP Gateway Docker access..."

# Check if Docker socket is accessible
if [ -S /var/run/docker.sock ]; then
    echo "✅ Docker socket exists"
    ls -la /var/run/docker.sock
else
    echo "❌ Docker socket not found"
    exit 1
fi

# Test Docker command access
echo "Testing Docker access..."
docker ps > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Docker command works"
else
    echo "❌ Docker command failed - check permissions"
    echo "Current user: $(whoami)"
    echo "Groups: $(groups)"
    exit 1
fi

# Start only MCP Gateway to test
echo "Starting MCP Gateway..."
docker compose up mcp-gateway

echo "If MCP Gateway starts successfully, you can then start all services:"
echo "  docker compose up -d"
