#!/bin/bash

echo "🔧 Fixing file permissions and Docker access..."

# Set correct permissions on secret files
chmod 600 secret.openai-api-key .mcp.env .env 2>/dev/null || true

# Ensure data directories exist with proper permissions
mkdir -p ./data/mongodb
chmod 755 ./data/mongodb

# Check Docker socket access
echo "Docker socket info:"
ls -la /var/run/docker.sock 2>/dev/null || echo "Docker socket not accessible"

# Check if user is in docker group
if groups | grep -q docker; then
    echo "✅ User is in docker group"
else
    echo "⚠️ User might need to be added to docker group:"
    echo "   sudo usermod -aG docker $USER"
    echo "   Then logout and login again"
fi

echo "✅ Permissions updated"
