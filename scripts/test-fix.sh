#!/bin/bash
# Test script to verify the npm fixes worked

echo "🧪 Testing npm fixes..."

# Wait a bit for containers to start
sleep 20

echo "📊 Container Status:"
docker compose ps

echo ""
echo "🔍 Testing endpoints..."

# Test agent health
if curl -s --max-time 10 http://localhost:3001/health | grep -q "healthy" 2>/dev/null; then
    echo "✅ Agent API is working"
else
    echo "❌ Agent API not responding"
    echo "📋 Agent logs:"
    docker compose logs --tail=10 mobyagent-core
fi

# Test UI
if curl -s --max-time 10 http://localhost:3000 >/dev/null 2>&1; then
    echo "✅ UI is responding"
else
    echo "❌ UI not responding"
    echo "📋 UI logs:"
    docker compose logs --tail=10 mobyagent-ui
fi

# Test MCP Gateway
if curl -s --max-time 5 http://localhost:8811 >/dev/null 2>&1; then
    echo "✅ MCP Gateway is responding"
else
    echo "⚠️  MCP Gateway may still be starting"
fi

echo ""
echo "🌐 Access URLs:"
echo "  Agent API: http://localhost:3001/health"
echo "  Web UI:    http://localhost:3000"
echo "  Vault:     http://localhost:8200"
echo ""
echo "📋 For detailed logs: docker compose logs -f [service-name]"
