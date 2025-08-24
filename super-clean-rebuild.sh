#!/bin/bash

echo "🚀 Super clean rebuild starting..."

# Force stop everything
docker compose kill 2>/dev/null || true
docker compose down --remove-orphans --volumes 2>/dev/null || true

# Clean Docker system
docker system prune -f
docker volume prune -f

# Remove specific images
docker rmi agentmoby-adk agentmoby-adk-ui 2>/dev/null || true

echo "🔨 Building services from scratch..."

# Build ADK service
echo "Building ADK..."
docker compose build --no-cache --pull adk

# Build ADK-UI service  
echo "Building ADK-UI..."
docker compose build --no-cache --pull adk-ui

echo "🗄️ Starting databases..."
docker compose up -d catalogue-db mongodb

echo "⏳ Waiting 25 seconds for databases..."
sleep 25

echo "🚀 Starting all services..."
docker compose up -d

echo "⏳ Final wait for services..."
sleep 10

echo ""
echo "✅ Rebuild complete!"
echo ""
echo "🌐 Access points:"
echo "  • AgentMoby Dashboard: http://localhost:3000"
echo "  • ADK API: http://localhost:8000"
echo "  • Sock Store: http://localhost:9090"
echo ""

# Test the services
echo "🧪 Quick connectivity test:"
curl -s http://localhost:3000/health > /dev/null && echo "✅ UI Service - OK" || echo "❌ UI Service - Failed"
curl -s http://localhost:8000/health > /dev/null && echo "✅ ADK Service - OK" || echo "❌ ADK Service - Failed"

echo ""
echo "📊 Container status:"
docker compose ps
