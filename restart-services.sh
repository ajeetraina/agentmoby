#!/bin/bash
echo "🔄 Restarting AgentMoby services..."
docker compose down
docker compose up -d
echo "✅ All services restarted"
