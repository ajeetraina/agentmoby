#!/bin/bash

# AgentMoby Complete Setup Script
# This script sets up the entire AgentMoby environment with all required configurations

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🐳 AgentMoby Setup Script${NC}"
echo "=================================="

# Function to print colored output
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check prerequisites
log_info "Checking prerequisites..."
command -v docker >/dev/null 2>&1 || { log_error "Docker is required but not installed. Please install Docker Desktop."; exit 1; }
command -v docker compose >/dev/null 2>&1 || { log_error "Docker Compose is required but not installed."; exit 1; }

# Check if Docker is running
docker info >/dev/null 2>&1 || { log_error "Docker is not running. Please start Docker Desktop."; exit 1; }

log_success "Docker and Docker Compose are available"

# Create project structure
log_info "Creating project structure..."
mkdir -p ./data/mongodb
mkdir -p ./configs
mkdir -p ./secrets

# Create environment file
log_info "Creating environment configuration..."
if [ ! -f .env ]; then
    cat > .env << 'EOF'
# MySQL Configuration
MYSQL_ROOT_PASSWORD=agentmoby-secure-password-123

# Application Settings
NODE_ENV=production
LOG_LEVEL=info
EOF
    log_success "Created .env file"
else
    log_warning ".env file already exists, skipping..."
fi

# Create OpenAI API key secret
log_info "Setting up OpenAI API key..."
if [ ! -f secret.openai-api-key ]; then
    read -p "Enter your OpenAI API key (or press Enter to use placeholder): " api_key
    if [ -z "$api_key" ]; then
        api_key="sk-placeholder-key-replace-with-real-key"
        log_warning "Using placeholder API key. Update secret.openai-api-key with your real key."
    fi
    echo "$api_key" > secret.openai-api-key
    chmod 600 secret.openai-api-key
    log_success "Created secret.openai-api-key"
else
    log_warning "secret.openai-api-key already exists, skipping..."
fi

# Create MCP environment file
log_info "Creating MCP configuration..."
if [ ! -f .mcp.env ]; then
    cat > .mcp.env << 'EOF'
# MCP Gateway Configuration
BRAVE_API_KEY=your-brave-api-key-here
RESEND_API_KEY=your-resend-api-key-here
MONGODB_URI=mongodb://admin:password@mongodb:27017/sockstore?authSource=admin

# Additional MCP Settings
MCP_LOG_LEVEL=info
MCP_TIMEOUT=30000
EOF
    log_success "Created .mcp.env file"
else
    log_warning ".mcp.env already exists, skipping..."
fi

# Create sample MongoDB initialization script
log_info "Creating MongoDB initialization..."
if [ ! -f ./data/mongodb/init.js ]; then
    cat > ./data/mongodb/init.js << 'EOF'
// MongoDB initialization script for sockstore
db = db.getSiblingDB('sockstore');

// Create collections
db.createCollection('products');
db.createCollection('users');
db.createCollection('orders');

// Insert sample data
db.products.insertMany([
  {
    id: "1",
    name: "Sample Sock",
    description: "A comfortable sock",
    price: 15.99,
    category: "socks"
  }
]);

print("Database initialized successfully");
EOF
    log_success "Created MongoDB initialization script"
fi

# Create Dockerfiles if they don't exist
log_info "Creating sample Dockerfiles..."

if [ ! -f Dockerfile ]; then
    cat > Dockerfile << 'EOF'
# Sample Dockerfile for ADK service
FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy application code
COPY . .

# Create non-root user
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nodejs -u 1001

# Change ownership and switch to non-root user
RUN chown -R nodejs:nodejs /app
USER nodejs

EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8000/health || exit 1

CMD ["npm", "start"]
EOF
    log_success "Created sample Dockerfile for ADK service"
fi

if [ ! -f Dockerfile.adk-ui ]; then
    cat > Dockerfile.adk-ui << 'EOF'
# Sample Dockerfile for ADK UI service
FROM node:18-alpine

WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm ci --only=production

# Copy application code
COPY ui/ ./

# Build the application
RUN npm run build

# Create non-root user
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nodejs -u 1001
RUN chown -R nodejs:nodejs /app
USER nodejs

EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

CMD ["npm", "start"]
EOF
    log_success "Created sample Dockerfile for ADK UI service"
fi

# Create sample package.json files
if [ ! -f package.json ]; then
    cat > package.json << 'EOF'
{
  "name": "agentmoby-adk",
  "version": "1.0.0",
  "description": "AgentMoby ADK Service",
  "main": "index.js",
  "scripts": {
    "start": "node index.js",
    "dev": "nodemon index.js"
  },
  "dependencies": {
    "express": "^4.18.0",
    "cors": "^2.8.5"
  }
}
EOF
fi

# Create corrected docker-compose.yml
log_info "Creating corrected docker-compose.yml..."
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  # Sock Store Frontend
  front-end:
    image: weaveworksdemos/front-end:0.3.12
    hostname: front-end
    ports:
      - "9090:8079"
    restart: unless-stopped
    cap_drop:
      - all
    read_only: true
    networks:
      - app-network
    healthcheck:
      test: ["CMD-SHELL", "wget --quiet --tries=1 --spider http://localhost:8079/ || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  # Catalogue Service
  catalogue:
    image: roberthouse224/catalogue:amd
    hostname: catalogue
    restart: unless-stopped
    cap_drop:
      - all
    cap_add:
      - NET_BIND_SERVICE
    read_only: true
    ports:
      - "8081:80"
    depends_on:
      catalogue-db:
        condition: service_healthy
    networks:
      - app-network
      - db-network
    healthcheck:
      test: ["CMD-SHELL", "wget --quiet --tries=1 --spider http://localhost:80/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  # Catalogue Database
  catalogue-db:
    image: weaveworksdemos/catalogue-db:0.3.0
    hostname: catalogue-db
    restart: unless-stopped
    environment:
      - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
      - MYSQL_ALLOW_EMPTY_PASSWORD=true
      - MYSQL_DATABASE=socksdb
    networks:
      - db-network
    volumes:
      - catalogue_db_data:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 20s
      timeout: 10s
      retries: 5
      start_period: 30s

  # MongoDB for Customer Reviews
  mongodb:
    image: mongo:7-jammy
    hostname: mongodb
    ports:
      - "27017:27017"
    environment:
      - MONGO_INITDB_ROOT_USERNAME=admin
      - MONGO_INITDB_ROOT_PASSWORD=password
      - MONGO_INITDB_DATABASE=sockstore
    volumes:
      - ./data/mongodb:/docker-entrypoint-initdb.d:ro
      - mongodb_data:/data/db
    networks:
      - db-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 20s
    command: [
      "mongod",
      "--quiet",
      "--logpath", "/var/log/mongodb/mongod.log",
      "--logappend"
    ]

  # MCP Gateway
  mcp-gateway:
    image: docker/mcp-gateway:latest
    hostname: mcp-gateway
    ports:
      - "8811:8811"
    command:
      - --transport=sse
      - --servers=fetch,brave,resend,curl,mongodb
      - --config=/mcp_config
      - --secrets=docker-desktop:/run/secrets/mcp_secret
      - --verbose
    configs:
      - mcp_config
    secrets:
      - mcp_secret
    depends_on:
      mongodb:
        condition: service_healthy
    networks:
      - app-network
      - db-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:8811/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  # ADK Core Service
  adk:
    build:
      context: .
      dockerfile: Dockerfile
    hostname: adk
    ports:
      - "8000:8000"
    environment:
      - MCPGATEWAY_ENDPOINT=http://mcp-gateway:8811/sse
      - CATALOGUE_URL=http://catalogue:80
      - OPENAI_BASE_URL=https://api.openai.com/v1
      - AI_DEFAULT_MODEL=openai/gpt-4
      - NODE_ENV=production
    depends_on:
      mcp-gateway:
        condition: service_healthy
      catalogue:
        condition: service_healthy
    secrets:
      - openai-api-key
    networks:
      - app-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:8000/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  # ADK UI Service
  adk-ui:
    build:
      context: .
      dockerfile: Dockerfile.adk-ui
    hostname: adk-ui
    ports:
      - "3000:3000"
    environment:
      - API_BASE_URL=http://adk:8000
      - NODE_ENV=production
    depends_on:
      adk:
        condition: service_healthy
    networks:
      - app-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:3000/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

networks:
  app-network:
    driver: bridge
    name: agentmoby_app
  db-network:
    driver: bridge
    name: agentmoby_db

volumes:
  mongodb_data:
    name: agentmoby_mongodb_data
  catalogue_db_data:
    name: agentmoby_catalogue_db

configs:
  mcp_config:
    content: |
      mongodb:
        uri: mongodb://admin:password@mongodb:27017/sockstore?authSource=admin
      resend:
        reply_to: slimslenderslacks@gmail.com
        sender: slimslenderslacks@slimslenderslacks.com
      brave:
        endpoint: https://api.search.brave.com/res/v1/web/search

secrets:
  openai-api-key:
    file: ./secret.openai-api-key
  mcp_secret:
    file: ./.mcp.env
EOF

log_success "Created corrected docker-compose.yml"

# Create sample application files
log_info "Creating sample application files..."

if [ ! -f index.js ]; then
    cat > index.js << 'EOF'
const express = require('express');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 8000;

app.use(cors());
app.use(express.json());

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

// Root endpoint
app.get('/', (req, res) => {
  res.json({ 
    message: 'AgentMoby ADK Service',
    version: '1.0.0',
    endpoints: {
      health: '/health',
      api: '/api'
    }
  });
});

// API endpoints
app.get('/api/status', (req, res) => {
  res.json({ 
    service: 'adk',
    status: 'running',
    mcpGateway: process.env.MCPGATEWAY_ENDPOINT,
    catalogueUrl: process.env.CATALOGUE_URL
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`ADK Service running on port ${PORT}`);
});
EOF
fi

# Create UI directory and files
mkdir -p ui

if [ ! -f ui/package.json ]; then
    cat > ui/package.json << 'EOF'
{
  "name": "agentmoby-ui",
  "version": "1.0.0",
  "description": "AgentMoby UI Service",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "express": "^4.18.0",
    "cors": "^2.8.5"
  }
}
EOF
fi

if [ ! -f ui/server.js ]; then
    cat > ui/server.js << 'EOF'
const express = require('express');
const cors = require('cors');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

// Root endpoint
app.get('/', (req, res) => {
  res.json({ 
    message: 'AgentMoby UI Service',
    version: '1.0.0',
    apiBaseUrl: process.env.API_BASE_URL
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`UI Service running on port ${PORT}`);
});
EOF
fi

# Set proper permissions
chmod 755 ./data/mongodb
chmod 600 secret.openai-api-key .mcp.env .env

# Create management scripts
log_info "Creating management scripts..."

cat > start-services.sh << 'EOF'
#!/bin/bash
echo "🐳 Starting AgentMoby services..."

# Start database services first
echo "Starting database services..."
docker compose up -d catalogue-db mongodb

echo "Waiting for databases to be ready..."
sleep 30

# Check database health
echo "Checking database health..."
docker compose ps | grep -E "(catalogue-db|mongodb)"

# Start MCP Gateway
echo "Starting MCP Gateway..."
docker compose up -d mcp-gateway

echo "Waiting for MCP Gateway..."
sleep 20

# Start application services
echo "Starting application services..."
docker compose up -d catalogue adk

echo "Waiting for application services..."
sleep 20

# Start UI services
echo "Starting UI services..."
docker compose up -d front-end adk-ui

echo "All services started! Access points:"
echo "  🌐 Frontend: http://localhost:9090"
echo "  🤖 Agent UI: http://localhost:3000"
echo "  🔌 MCP Gateway: http://localhost:8811"
echo "  📊 ADK API: http://localhost:8000"
echo "  🗄️ Catalogue: http://localhost:8081"
echo ""
echo "Check status: docker compose ps"
echo "View logs: docker compose logs -f [service_name]"
EOF

cat > stop-services.sh << 'EOF'
#!/bin/bash
echo "🛑 Stopping AgentMoby services..."
docker compose down
echo "✅ All services stopped"
EOF

cat > restart-services.sh << 'EOF'
#!/bin/bash
echo "🔄 Restarting AgentMoby services..."
docker compose down
docker compose up -d
echo "✅ All services restarted"
EOF

cat > check-status.sh << 'EOF'
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
EOF

chmod +x start-services.sh stop-services.sh restart-services.sh check-status.sh

log_success "Created management scripts"

# Try to pull the Docker Model Runner model
log_info "Attempting to pull AI model for Docker Model Runner..."
if command -v docker-model >/dev/null 2>&1 || docker model --help >/dev/null 2>&1; then
    docker model pull ai/qwen3:14B-Q6_K || log_warning "Could not pull AI model. Ensure Docker Desktop with Model Runner is installed."
else
    log_warning "Docker Model Runner not detected. Install Docker Desktop with Model Runner feature."
fi

# Final setup summary
log_success "🎉 AgentMoby setup complete!"
echo ""
echo "📁 Created files:"
echo "  ├── docker-compose.yml (corrected configuration)"
echo "  ├── .env (environment variables)"
echo "  ├── secret.openai-api-key (API key)"
echo "  ├── .mcp.env (MCP configuration)"
echo "  ├── Dockerfile & Dockerfile.adk-ui (sample containers)"
echo "  ├── package.json & index.js (sample ADK service)"
echo "  ├── ui/ (sample UI service)"
echo "  ├── data/mongodb/ (database initialization)"
echo "  └── Management scripts (start/stop/restart/check)"
echo ""
echo "🚀 Next steps:"
echo "  1. Update secret.openai-api-key with your real OpenAI API key"
echo "  2. Update .mcp.env with your actual API keys (Brave, Resend, etc.)"
echo "  3. Run: ./start-services.sh"
echo "  4. Check status: ./check-status.sh"
echo ""
echo "🌐 Access points (once running):"
echo "  • Frontend: http://localhost:9090"
echo "  • Agent UI: http://localhost:3000"  
echo "  • MCP Gateway: http://localhost:8811"
echo "  • ADK API: http://localhost:8000"
echo "  • Catalogue: http://localhost:8081"
echo ""
echo "🔧 Troubleshooting:"
echo "  • View logs: docker compose logs -f [service_name]"
echo "  • Check service health: ./check-status.sh"
echo "  • Restart all: ./restart-services.sh"
EOF
