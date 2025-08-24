#!/bin/bash
echo "🔄 Rebuilding all services..."

# Stop all services
docker compose down

# Remove old images
docker compose build --no-cache

# Start services in order
echo "Starting databases..."
docker compose up -d catalogue-db mongodb

echo "Waiting for databases..."
sleep 20

echo "Starting MCP Gateway..."
docker compose up -d mcp-gateway

echo "Waiting for MCP Gateway..."
sleep 15

echo "Starting core services..."
docker compose up -d catalogue adk

echo "Waiting for core services..."
sleep 15

echo "Starting UI services..."
docker compose up -d front-end adk-ui

echo "✅ All services rebuilt and started!"
echo ""
echo "🌐 Access points:"
echo "  • AgentMoby UI: http://localhost:3000"
echo "  • Sock Store: http://localhost:9090"  
echo "  • ADK API: http://localhost:8000"
echo "  • MCP Gateway: http://localhost:8811"
echo "  • Catalogue: http://localhost:8081"

docker compose ps
