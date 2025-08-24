#!/bin/bash

echo "🔍 Verifying all services..."
echo ""

echo "📦 Container Status:"
docker compose ps
echo ""

echo "🌐 Service Health Checks:"
services=(
    "http://localhost:3000/health|UI Service"
    "http://localhost:8000/health|ADK API"
    "http://localhost:9090|Frontend"
    "http://localhost:8081|Catalogue"
)

for service in "${services[@]}"; do
    url=$(echo $service | cut -d'|' -f1)
    name=$(echo $service | cut -d'|' -f2)
    
    if curl -s -f "$url" > /dev/null 2>&1; then
        echo "✅ $name - Responding"
    else
        echo "❌ $name - Not responding"
    fi
done

echo ""
echo "📋 Recent logs (UI Service):"
docker compose logs --tail=5 adk-ui

echo ""
echo "📋 Recent logs (ADK Service):"  
docker compose logs --tail=5 adk
