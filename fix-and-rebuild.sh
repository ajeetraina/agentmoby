#!/bin/bash

echo "🔧 Fixing syntax issues and rebuilding..."

# Stop everything
docker compose down

# Remove old images to force rebuild
docker compose rm -f adk adk-ui
docker image rm agentmoby-adk agentmoby-adk-ui 2>/dev/null || true

# Rebuild with no cache
echo "🔨 Building ADK service..."
docker compose build --no-cache adk

echo "🔨 Building ADK UI service..."
docker compose build --no-cache adk-ui

# Start databases first
echo "🗄️ Starting databases..."
docker compose up -d catalogue-db mongodb

echo "⏳ Waiting for databases to initialize..."
sleep 20

# Start other services
echo "🚀 Starting all services..."
docker compose up -d

echo "⏳ Waiting for services to be ready..."
sleep 15

echo "✅ Services started!"
echo ""
echo "🌐 Access points:"
echo "  • AgentMoby UI: http://localhost:3000"
echo "  • Sock Store:   http://localhost:9090"
echo "  • ADK API:      http://localhost:8000"
echo "  • Catalogue:    http://localhost:8081"

echo ""
echo "📊 Service Status:"
docker compose ps

echo ""
echo "🔍 Test the services:"
echo "  curl http://localhost:3000/health"
echo "  curl http://localhost:8000/health"
