#!/bin/bash
echo "🧪 Testing JavaScript syntax..."

echo "Testing index.js:"
node -c index.js && echo "✅ index.js syntax OK" || echo "❌ index.js has syntax errors"

echo "Testing ui/server.js:"
node -c ui/server.js && echo "✅ ui/server.js syntax OK" || echo "❌ ui/server.js has syntax errors"

echo "✅ Syntax check complete"
