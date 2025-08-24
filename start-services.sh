#!/bin/bash
echo "🐳 Starting AgentMoby services..."

# Start database services first
echo "Starting database services..."
docker compose up -d catalogue-db mongodb

echo "Waiting for databases to be ready..."
sleep 30

# Check database health
echo "Checking database health..."
docker compose ps | grep -E "(catalogue-db|mongodb)"

# Start MCP Gateway
echo "Starting MCP Gateway..."
docker compose up -d mcp-gateway

echo "Waiting for MCP Gateway..."
sleep 20

# Start application services
echo "Starting application services..."
docker compose up -d catalogue adk

echo "Waiting for application services..."
sleep 20

# Start UI services
echo "Starting UI services..."
docker compose up -d front-end adk-ui

echo "All services started! Access points:"
echo "  🌐 Frontend: http://localhost:9090"
echo "  🤖 Agent UI: http://localhost:3000"
echo "  🔌 MCP Gateway: http://localhost:8811"
echo "  📊 ADK API: http://localhost:8000"
echo "  🗄️ Catalogue: http://localhost:8081"
echo ""
echo "Check status: docker compose ps"
echo "View logs: docker compose logs -f [service_name]"
