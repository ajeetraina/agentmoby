#!/bin/bash
# Quick fix for the npm --only=production error in MobyAgent

echo "🔧 Quick Fix: npm --only=production Error"
echo ""

# Check if we're in a MobyAgent directory
if [ ! -f "compose.yaml" ] || [ ! -d "agent" ]; then
    echo "❌ This doesn't appear to be a MobyAgent directory"
    echo "   Run this script from the directory containing compose.yaml"
    exit 1
fi

echo "🛠️  Fixing npm compatibility issue..."

# Stop the failing container
echo "⏹️  Stopping containers..."
docker compose down

# Fix the agent Dockerfile
echo "📝 Updating agent Dockerfile..."
cat > agent/Dockerfile << 'EOF'
FROM node:18-alpine

# Update npm and set compatibility flags
RUN npm install -g npm@latest && \
    npm config set fund false && \
    npm config set audit-level moderate

# Create app directory and user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S mobyagent -u 1001 -G nodejs

WORKDIR /app

# Copy package files
COPY package*.json ./

# Use npm install instead of ci with omit flag (npm 7+ syntax)
RUN npm install --omit=dev && npm cache clean --force

# Copy source code
COPY --chown=mobyagent:nodejs . .

# Install curl for health checks
RUN apk add --no-cache curl

# Create data directory
RUN mkdir -p /app/data && chown mobyagent:nodejs /app/data

# Switch to non-root user
USER mobyagent

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3001/health || exit 1

EXPOSE 3001

CMD ["node", "src/index.js"]
EOF

# Fix the UI Dockerfile too
echo "📝 Updating UI Dockerfile..."
cat > ui/Dockerfile << 'EOF'
FROM node:18-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm ci && npm cache clean --force
COPY . .
RUN npm run build

FROM node:18-alpine AS runner

RUN addgroup -g 1001 -S nodejs && \
    adduser -S nextjs -u 1001 -G nodejs

WORKDIR /app

# Copy built application
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
COPY --from=builder --chown=nextjs:nodejs /app/public ./public

USER nextjs

EXPOSE 3000
ENV PORT 3000

CMD ["node", "server.js"]
EOF

# Create .dockerignore to speed up builds
cat > .dockerignore << 'EOF'
node_modules
npm-debug.log*
.npm
.git
.gitignore
README.md
.dockerignore
.next
.vscode
coverage
.env.local
EOF

echo "🔄 Rebuilding containers with fixed configuration..."
docker compose build --no-cache

echo "🚀 Starting containers..."
docker compose up -d

echo "⏳ Waiting for services to start..."
sleep 20

echo "🧪 Testing the fix..."
if curl -s http://localhost:3001/health | grep -q "healthy"; then
    echo "✅ Fix successful! Agent is responding"
    echo ""
    echo "🌐 Access your services:"
    echo "   Web UI: http://localhost:3000" 
    echo "   Agent API: http://localhost:3001"
    echo "   MCP Gateway: http://localhost:8811"
    echo ""
    echo "Check status: docker compose ps"
else
    echo "⚠️  Services may still be starting up..."
    echo "   Check logs: docker compose logs -f"
    echo "   Check status: docker compose ps"
fi

echo ""
echo "🎉 npm compatibility fix applied!"
echo ""
echo "If you still have issues:"
echo "  1. Check logs: docker compose logs mobyagent-core"
echo "  2. Restart: docker compose restart"
echo "  3. Full rebuild: docker compose down && docker compose up --build"
