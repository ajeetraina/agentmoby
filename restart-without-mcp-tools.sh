#!/bin/bash
echo "🔄 Restarting without MCP tool dependencies..."

# Stop all services
docker compose down

# Start services without MCP Gateway initially
echo "Starting databases..."
docker compose up -d catalogue-db mongodb

echo "Waiting for databases..."
sleep 25

echo "Starting core services..."
docker compose up -d catalogue front-end

echo "Starting ADK without MCP dependency..."
docker compose up -d adk

echo "Starting UI..."
docker compose up -d adk-ui

echo "✅ Core services started! You can try MCP Gateway later:"
echo "  docker compose up -d mcp-gateway"

echo ""
echo "🌐 Access points:"
echo "  • AgentMoby UI: http://localhost:3000"
echo "  • Sock Store: http://localhost:9090"  
echo "  • ADK API: http://localhost:8000"
echo "  • Catalogue: http://localhost:8081"

docker compose ps
