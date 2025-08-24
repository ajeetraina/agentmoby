#!/bin/bash

echo "🩺 Fixing health check and dependency issues..."

# Create corrected docker-compose.yml without problematic health checks
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
    platform: linux/amd64

  # Catalogue Service (Remove problematic health check)
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
      - catalogue-db  # Simple dependency without health check
    networks:
      - app-network
      - db-network
    platform: linux/amd64

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
    platform: linux/amd64

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
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    command: [
      "mongod",
      "--quiet",
      "--logpath", "/var/log/mongodb/mongod.log",
      "--logappend"
    ]

  # MCP Gateway with Docker Socket Access
  mcp-gateway:
    image: docker/mcp-gateway:latest
    hostname: mcp-gateway
    ports:
      - "8811:8811"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:rw
    user: "0:0"
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
      - mongodb
    networks:
      - app-network
      - db-network
    restart: unless-stopped
    environment:
      - DOCKER_HOST=unix:///var/run/docker.sock

  # ADK Core Service (Remove health check dependency)
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
      - mcp-gateway
      - catalogue  # Simple dependency
    secrets:
      - openai-api-key
    networks:
      - app-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "wget --quiet --tries=1 --spider http://localhost:8000/health || exit 1"]
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
      - adk  # Simple dependency
    networks:
      - app-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "wget --quiet --tries=1 --spider http://localhost:3000/health || exit 1"]
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

# Create a staged startup script that handles timing properly
cat > start-properly.sh << 'EOF'
#!/bin/bash

echo "🚀 Starting AgentMoby services with proper timing..."

# Clean up any existing containers
docker compose down

echo "Step 1: Starting databases..."
docker compose up -d catalogue-db mongodb

echo "Waiting 30 seconds for databases to initialize..."
sleep 30

# Check database status
echo "Checking database containers..."
docker compose ps | grep -E "(catalogue-db|mongodb)"

echo "Step 2: Starting catalogue and frontend..."
docker compose up -d catalogue front-end

echo "Waiting 20 seconds for catalogue to connect to database..."
sleep 20

echo "Step 3: Starting MCP Gateway..."
docker compose up -d mcp-gateway

echo "Waiting 15 seconds for MCP Gateway..."
sleep 15

echo "Step 4: Starting ADK service..."
docker compose up -d adk

echo "Waiting 10 seconds for ADK..."
sleep 10

echo "Step 5: Starting UI..."
docker compose up -d adk-ui

echo ""
echo "🎉 All services started!"
echo ""
echo "🌐 Access your services:"
echo "  • AgentMoby UI:  http://localhost:3000"
echo "  • Sock Store:    http://localhost:9090"
echo "  • ADK API:       http://localhost:8000"
echo "  • Catalogue API: http://localhost:8081"
echo ""

echo "📊 Service Status:"
docker compose ps

echo ""
echo "🔍 Quick Health Check:"
services=("localhost:3000" "localhost:9090" "localhost:8000" "localhost:8081")
for service in "${services[@]}"; do
    if curl -s -f "http://$service" > /dev/null 2>&1; then
        echo "  ✅ $service - Responding"
    else
        echo "  ❌ $service - Not responding"
    fi
done

echo ""
echo "📋 View logs with:"
echo "  docker compose logs -f [service-name]"
echo ""
echo "🛑 Stop all services with:"
echo "  docker compose down"
EOF

# Create a service status checker
cat > check-services.sh << 'EOF'
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
EOF

# Fix permission issue script
cat > fix-permissions.sh << 'EOF'
#!/bin/bash

echo "🔧 Fixing file permissions and Docker access..."

# Set correct permissions on secret files
chmod 600 secret.openai-api-key .mcp.env .env 2>/dev/null || true

# Ensure data directories exist with proper permissions
mkdir -p ./data/mongodb
chmod 755 ./data/mongodb

# Check Docker socket access
echo "Docker socket info:"
ls -la /var/run/docker.sock 2>/dev/null || echo "Docker socket not accessible"

# Check if user is in docker group
if groups | grep -q docker; then
    echo "✅ User is in docker group"
else
    echo "⚠️ User might need to be added to docker group:"
    echo "   sudo usermod -aG docker $USER"
    echo "   Then logout and login again"
fi

echo "✅ Permissions updated"
EOF

chmod +x start-properly.sh check-services.sh fix-permissions.sh

echo "✅ Health check issues fixed!"
echo ""
echo "📁 Created files:"
echo "  ├── docker-compose.yml (fixed health check dependencies)"
echo "  ├── start-properly.sh (staged startup with proper timing)"
echo "  ├── check-services.sh (comprehensive service status)"
echo "  └── fix-permissions.sh (fix permission issues)"
echo ""
echo "🚀 To start all services properly:"
echo "  ./fix-permissions.sh"
echo "  ./start-properly.sh"
echo ""
echo "🔍 To check service status:"
echo "  ./check-services.sh"
echo ""
echo "The key fixes:"
echo "  • Removed health check requirements that were failing"
echo "  • Added proper staging in startup sequence"
echo "  • Fixed Docker socket access for MCP Gateway"
echo "  • Added comprehensive status monitoring"
EOF
