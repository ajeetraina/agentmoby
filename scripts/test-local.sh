#!/bin/bash
# MobyAgent Local Testing Script

echo "🧪 Testing MobyAgent locally..."

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 30

# Test health endpoints
echo "🔍 Testing health endpoints..."

# Agent health
if curl -s http://localhost:3001/health | grep -q "healthy"; then
    echo "✅ Agent health check passed"
else
    echo "❌ Agent health check failed"
fi

# Test basic chat
echo "🤖 Testing chat functionality..."
CHAT_RESPONSE=$(curl -s -X POST http://localhost:3001/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello MobyAgent!"}')

if echo "$CHAT_RESPONSE" | grep -q "response"; then
    echo "✅ Chat functionality working"
else
    echo "❌ Chat functionality failed"
    echo "Response: $CHAT_RESPONSE"
fi

# Test MCP Gateway (basic)
echo "🔧 Testing MCP Gateway..."
if curl -s http://localhost:8811 > /dev/null 2>&1; then
    echo "✅ MCP Gateway responding"
else
    echo "❌ MCP Gateway not responding"
fi

# Test Vault
echo "🔐 Testing Vault..."
if curl -s http://localhost:8200/v1/sys/health > /dev/null 2>&1; then
    echo "✅ Vault responding"
else
    echo "❌ Vault not responding"
fi

# Test UI
echo "🌐 Testing UI..."
if curl -s http://localhost:3000 | grep -q "MobyAgent"; then
    echo "✅ UI responding"
else
    echo "❌ UI not responding"
fi

echo ""
echo "🐳 MobyAgent test summary:"
echo "- Agent API: http://localhost:3001"
echo "- MCP Gateway: http://localhost:8811"
echo "- Web UI: http://localhost:3000"
echo "- Vault: http://localhost:8200"
echo ""
echo "Check logs with: docker compose logs -f"
