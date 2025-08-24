#!/bin/bash
echo "📊 AgentMoby Service Status"
echo "=========================="
docker compose ps

echo ""
echo "🏥 Health Checks"
echo "================"

services=("front-end:9090" "adk-ui:3000" "adk:8000" "mcp-gateway:8811" "catalogue:8081")

for service in "${services[@]}"; do
    IFS=':' read -r name port <<< "$service"
    if curl -s -f "http://localhost:$port/health" > /dev/null 2>&1; then
        echo "✅ $name (port $port) - Healthy"
    else
        echo "❌ $name (port $port) - Unhealthy"
    fi
done

echo ""
echo "🐘 Database Status"
echo "=================="
docker compose exec mongodb mongosh --eval "db.adminCommand('ping')" > /dev/null 2>&1 && echo "✅ MongoDB - Connected" || echo "❌ MongoDB - Disconnected"
docker compose exec catalogue-db mysqladmin ping -h localhost > /dev/null 2>&1 && echo "✅ MySQL - Connected" || echo "❌ MySQL - Disconnected"
