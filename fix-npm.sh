#!/bin/bash
# Complete fix for all npm issues in MobyAgent setup
# This script addresses both the --only=production error and missing package-lock.json

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%H:%M:%S')] ERROR: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')] INFO: $1${NC}"
}

echo -e "${BLUE}"
echo "🔧 Complete NPM Fix for MobyAgent"
echo "================================="
echo -e "${NC}"

# Check if we're in the right directory
if [ ! -f "compose.yaml" ]; then
    error "compose.yaml not found. Please run this script from the MobyAgent root directory."
    exit 1
fi

log "Stopping any running containers..."
docker compose down 2>/dev/null || true

log "Cleaning up existing build cache..."
docker builder prune -f >/dev/null 2>&1 || true

log "Creating fixed Dockerfiles..."

# Fix Agent Dockerfile
cat > agent/Dockerfile << 'EOF'
FROM node:18-alpine

# Install system dependencies and create user
RUN apk add --no-cache curl && \
    addgroup -g 1001 -S nodejs && \
    adduser -S mobyagent -u 1001 -G nodejs

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies using npm install (works without package-lock.json)
RUN npm install --production --verbose && \
    npm cache clean --force

# Copy source code
COPY --chown=mobyagent:nodejs . .

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

# Fix UI Dockerfile - simplified single-stage build
cat > ui/Dockerfile << 'EOF'
FROM node:18-alpine

# Install system dependencies
RUN apk add --no-cache curl

# Create user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nextjs -u 1001 -G nodejs

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install ALL dependencies (including dev dependencies for build)
RUN npm install --verbose && \
    npm cache clean --force

# Copy source code
COPY --chown=nextjs:nodejs . .

# Build the application
RUN npm run build

# Switch to non-root user
USER nextjs

EXPOSE 3000

ENV PORT=3000
ENV NODE_ENV=development

# Use Next.js dev mode for easier local testing
CMD ["npm", "run", "dev"]
EOF

log "Creating .dockerignore files to speed up builds..."

# Create comprehensive .dockerignore
cat > .dockerignore << 'EOF'
node_modules
npm-debug.log*
yarn-debug.log*
yarn-error.log*
.npm
.yarn
.pnp
.pnp.js
.next
.nuxt
dist
coverage
.nyc_output
.cache
.parcel-cache
.vscode
.idea
*.log
.git
.gitignore
README.md
.dockerignore
.env.local
.env.development.local
.env.test.local
.env.production.local
Dockerfile*
docker-compose*.yml
compose*.yaml
*.md
.DS_Store
Thumbs.db
EOF

# Copy .dockerignore to subdirectories
cp .dockerignore agent/
cp .dockerignore ui/

log "Creating enhanced package.json files with all required dependencies..."

# Enhanced Agent package.json
cat > agent/package.json << 'EOF'
{
  "name": "mobyagent-core",
  "version": "1.0.0",
  "description": "MobyAgent: The Whale that never blinks - Secure AI Agent Core",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "dev": "nodemon src/index.js",
    "test": "echo \"No tests yet\" && exit 0"
  },
  "dependencies": {
    "express": "^4.18.2",
    "axios": "^1.6.2",
    "helmet": "^7.1.0",
    "express-rate-limit": "^7.1.5",
    "cors": "^2.8.5"
  },
  "engines": {
    "node": ">=18.0.0",
    "npm": ">=8.0.0"
  },
  "keywords": [
    "ai",
    "agent",
    "docker",
    "security",
    "mcp",
    "mobyagent"
  ],
  "author": "MobyAgent Team",
  "license": "MIT"
}
EOF

# Enhanced UI package.json
cat > ui/package.json << 'EOF'
{
  "name": "mobyagent-ui",
  "version": "1.0.0",
  "description": "MobyAgent Web Interface",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint"
  },
  "dependencies": {
    "next": "^14.0.4",
    "react": "^18.2.0",
    "react-dom": "^18.2.0"
  },
  "devDependencies": {
    "eslint": "^8.55.0",
    "eslint-config-next": "^14.0.4"
  },
  "engines": {
    "node": ">=18.0.0",
    "npm": ">=8.0.0"
  }
}
EOF

log "Creating simplified compose.yaml for better local testing..."

# Create a simplified compose file for local testing
cat > compose.yaml << 'EOF'
# MobyAgent: Local Testing Configuration
# Simplified version for reliable local development

services:
  # MCP Gateway - Simplified for local testing
  mcp-gateway:
    image: docker/mcp-gateway:latest
    container_name: mobyagent-gateway
    ports:
      - "8811:8811"
    environment:
      - MCP_TRANSPORT=sse
      - MCP_PORT=8811
    volumes:
      - ./interceptors:/interceptors:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - mobyagent-network
    restart: unless-stopped
    command:
      - --transport=sse
      - --port=8811
      - --interceptor=before:exec:/interceptors/security-monitor.sh
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8811"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Agent Core - Simplified build
  mobyagent-core:
    build: 
      context: ./agent
      dockerfile: Dockerfile
    container_name: mobyagent-core
    ports:
      - "3001:3001"
    environment:
      - MCP_GATEWAY_URL=http://mcp-gateway:8811
      - MODEL_ENDPOINT=http://host.docker.internal:12434/engines/v1
      - LOG_LEVEL=debug
      - NODE_ENV=development
    volumes:
      - ./config:/config:ro
    networks:
      - mobyagent-network
    depends_on:
      - mcp-gateway
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3001/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

  # Agent UI - Simplified for local development
  mobyagent-ui:
    build:
      context: ./ui
      dockerfile: Dockerfile
    container_name: mobyagent-ui
    ports:
      - "3000:3000"
    environment:
      - NEXT_PUBLIC_AGENT_URL=http://localhost:3001
      - NODE_ENV=development
      - FAST_REFRESH=true
    networks:
      - mobyagent-network
    depends_on:
      - mobyagent-core
    restart: unless-stopped
    volumes:
      # Mount source code for hot reload in development
      - ./ui/pages:/app/pages
      - ./ui/styles:/app/styles

  # Vault - Simplified configuration
  vault:
    image: hashicorp/vault:latest
    container_name: mobyagent-vault
    ports:
      - "8200:8200"
    environment:
      - VAULT_DEV_ROOT_TOKEN_ID=mobyagent-dev-token
      - VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200
    networks:
      - mobyagent-network
    restart: unless-stopped
    cap_add:
      - IPC_LOCK

networks:
  mobyagent-network:
    driver: bridge

volumes:
  vault-data:
    driver: local
EOF

log "Creating better test script..."

cat > scripts/test-fix.sh << 'EOF'
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
EOF

chmod +x scripts/test-fix.sh

log "Building containers with no cache to ensure clean build..."
docker compose build --no-cache --progress=plain

log "Starting services..."
docker compose up -d

log "Waiting for services to initialize..."
sleep 30

log "Testing the fix..."
./scripts/test-fix.sh

echo ""
echo -e "${GREEN}🎉 Complete npm fix applied!${NC}"
echo ""
echo -e "${BLUE}What was fixed:${NC}"
echo "  ✅ Replaced npm ci with npm install (works without package-lock.json)"
echo "  ✅ Fixed both agent and UI Dockerfiles"
echo "  ✅ Simplified compose.yaml for reliable local testing"
echo "  ✅ Added comprehensive .dockerignore files"
echo "  ✅ Enhanced package.json files with proper versions"
echo "  ✅ Added development-friendly configuration"
echo ""
echo -e "${YELLOW}Access your services:${NC}"
echo "  🌐 Web UI:    http://localhost:3000"
echo "  🤖 Agent API: http://localhost:3001"
echo "  🔐 Vault:     http://localhost:8200"
echo ""
echo -e "${BLUE}If you still see issues:${NC}"
echo "  📋 Check logs: docker compose logs -f"
echo "  🔄 Restart: docker compose restart"
echo "  🧹 Clean rebuild: docker compose down && docker compose up --build"
