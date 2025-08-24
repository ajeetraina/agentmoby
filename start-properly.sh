#!/bin/bash

echo "🚀 Starting AgentMoby services with proper timing..."

# Clean up any existing containers
docker compose down

echo "Step 1: Starting databases..."
docker compose up -d catalogue-db mongodb

echo "Waiting 30 seconds for databases to initialize..."
sleep 30

# Check database status
echo "Checking database containers..."
docker compose ps | grep -E "(catalogue-db|mongodb)"

echo "Step 2: Starting catalogue and frontend..."
docker compose up -d catalogue front-end

echo "Waiting 20 seconds for catalogue to connect to database..."
sleep 20

echo "Step 3: Starting MCP Gateway..."
docker compose up -d mcp-gateway

echo "Waiting 15 seconds for MCP Gateway..."
sleep 15

echo "Step 4: Starting ADK service..."
docker compose up -d adk

echo "Waiting 10 seconds for ADK..."
sleep 10

echo "Step 5: Starting UI..."
docker compose up -d adk-ui

echo ""
echo "🎉 All services started!"
echo ""
echo "🌐 Access your services:"
echo "  • AgentMoby UI:  http://localhost:3000"
echo "  • Sock Store:    http://localhost:9090"
echo "  • ADK API:       http://localhost:8000"
echo "  • Catalogue API: http://localhost:8081"
echo ""

echo "📊 Service Status:"
docker compose ps

echo ""
echo "🔍 Quick Health Check:"
services=("localhost:3000" "localhost:9090" "localhost:8000" "localhost:8081")
for service in "${services[@]}"; do
    if curl -s -f "http://$service" > /dev/null 2>&1; then
        echo "  ✅ $service - Responding"
    else
        echo "  ❌ $service - Not responding"
    fi
done

echo ""
echo "📋 View logs with:"
echo "  docker compose logs -f [service-name]"
echo ""
echo "🛑 Stop all services with:"
echo "  docker compose down"
