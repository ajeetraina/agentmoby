#!/bin/bash
echo "🔄 Rebuilding UI service..."
docker compose stop adk-ui
docker compose build --no-cache adk-ui
docker compose up -d adk-ui
echo "✅ UI service rebuilt and started"
docker compose logs -f adk-ui
