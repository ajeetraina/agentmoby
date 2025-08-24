#!/bin/bash

echo "🔍 AgentMoby Service Status Check"
echo "================================"
echo ""

# Check container status
echo "📦 Container Status:"
docker compose ps

echo ""
echo "🌐 Service Connectivity:"

# Check each service
services=(
    "localhost:3000|AgentMoby UI"
    "localhost:9090|Sock Store Frontend" 
    "localhost:8000|ADK API"
    "localhost:8081|Catalogue API"
    "localhost:8811|MCP Gateway"
    "localhost:27017|MongoDB"
)

for entry in "${services[@]}"; do
    IFS='|' read -r url name <<< "$entry"
    
    if [[ $url == *"27017"* ]]; then
        # Special check for MongoDB
        if docker compose exec mongodb mongosh --quiet --eval "db.adminCommand('ping')" > /dev/null 2>&1; then
            echo "  ✅ $name ($url) - Connected"
        else
            echo "  ❌ $name ($url) - Not responding"
        fi
    else
        # HTTP check
        if curl -s -f "http://$url" > /dev/null 2>&1; then
            echo "  ✅ $name ($url) - Responding"
        else
            echo "  ❌ $name ($url) - Not responding"
        fi
    fi
done

echo ""
echo "📋 Recent Logs (last 10 lines each):"
for service in adk-ui adk mcp-gateway catalogue front-end; do
    echo ""
    echo "--- $service ---"
    docker compose logs --tail=5 $service 2>/dev/null || echo "Service not running"
done

echo ""
echo "🔧 Troubleshooting:"
echo "  • View full logs: docker compose logs -f [service-name]"
echo "  • Restart service: docker compose restart [service-name]"  
echo "  • Rebuild service: docker compose up -d --build [service-name]"
