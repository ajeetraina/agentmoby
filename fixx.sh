#!/bin/bash

echo "🔧 Fixing MCP Gateway Docker Socket Access..."

# Create updated docker-compose.yml with proper Docker socket mounting
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
    platform: linux/amd64  # Force AMD64 for compatibility

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
    platform: linux/amd64  # Force AMD64 for compatibility

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
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root"]
      interval: 20s
      timeout: 10s
      retries: 5
      start_period: 30s
    platform: linux/amd64  # Force AMD64 for compatibility

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

  # MCP Gateway with Docker Socket Access
  mcp-gateway:
    image: docker/mcp-gateway:latest
    hostname: mcp-gateway
    ports:
      - "8811:8811"
    # CRITICAL: Mount Docker socket for MCP tools
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:rw
    # Add docker group permissions
    user: "0:0"  # Run as root to access docker socket
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
    # Remove health check as it may interfere
    environment:
      - DOCKER_HOST=unix:///var/run/docker.sock

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
        condition: service_started  # Changed from healthy
      catalogue:
        condition: service_healthy
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
      adk:
        condition: service_healthy
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

# Create a simple restart script without the problematic MCP tools
cat > restart-without-mcp-tools.sh << 'EOF'
#!/bin/bash
echo "🔄 Restarting without MCP tool dependencies..."

# Stop all services
docker compose down

# Start services without MCP Gateway initially
echo "Starting databases..."
docker compose up -d catalogue-db mongodb

echo "Waiting for databases..."
sleep 25

echo "Starting core services..."
docker compose up -d catalogue front-end

echo "Starting ADK without MCP dependency..."
docker compose up -d adk

echo "Starting UI..."
docker compose up -d adk-ui

echo "✅ Core services started! You can try MCP Gateway later:"
echo "  docker compose up -d mcp-gateway"

echo ""
echo "🌐 Access points:"
echo "  • AgentMoby UI: http://localhost:3000"
echo "  • Sock Store: http://localhost:9090"  
echo "  • ADK API: http://localhost:8000"
echo "  • Catalogue: http://localhost:8081"

docker compose ps
EOF

# Create MCP Gateway test script
cat > test-mcp-gateway.sh << 'EOF'
#!/bin/bash
echo "🧪 Testing MCP Gateway Docker access..."

# Check if Docker socket is accessible
if [ -S /var/run/docker.sock ]; then
    echo "✅ Docker socket exists"
    ls -la /var/run/docker.sock
else
    echo "❌ Docker socket not found"
    exit 1
fi

# Test Docker command access
echo "Testing Docker access..."
docker ps > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Docker command works"
else
    echo "❌ Docker command failed - check permissions"
    echo "Current user: $(whoami)"
    echo "Groups: $(groups)"
    exit 1
fi

# Start only MCP Gateway to test
echo "Starting MCP Gateway..."
docker compose up mcp-gateway

echo "If MCP Gateway starts successfully, you can then start all services:"
echo "  docker compose up -d"
EOF

# Create alternative docker-compose without MCP Gateway for testing
cat > docker-compose.simple.yml << 'EOF'
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
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root"]
      interval: 20s
      timeout: 10s
      retries: 5
      start_period: 30s
    platform: linux/amd64

  # MongoDB
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

  # ADK Core Service (without MCP dependency)
  adk:
    build:
      context: .
      dockerfile: Dockerfile
    hostname: adk
    ports:
      - "8000:8000"
    environment:
      - MCPGATEWAY_ENDPOINT=http://localhost:8811/sse  # Optional
      - CATALOGUE_URL=http://catalogue:80
      - OPENAI_BASE_URL=https://api.openai.com/v1
      - AI_DEFAULT_MODEL=openai/gpt-4
      - NODE_ENV=production
    depends_on:
      catalogue:
        condition: service_healthy
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
      adk:
        condition: service_healthy
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

secrets:
  openai-api-key:
    file: ./secret.openai-api-key
  mcp_secret:
    file: ./.mcp.env
EOF

chmod +x restart-without-mcp-tools.sh test-mcp-gateway.sh

echo "✅ Created fixes for MCP Gateway issues!"
echo ""
echo "📁 Files created:"
echo "  ├── docker-compose.yml (with Docker socket mount)"
echo "  ├── docker-compose.simple.yml (without MCP Gateway)"
echo "  ├── restart-without-mcp-tools.sh"
echo "  └── test-mcp-gateway.sh"
echo ""
echo "🚀 Try these options:"
echo ""
echo "Option 1 - Simple restart without MCP issues:"
echo "  ./restart-without-mcp-tools.sh"
echo ""
echo "Option 2 - Test MCP Gateway Docker access:"
echo "  ./test-mcp-gateway.sh"
echo ""
echo "Option 3 - Use simple compose file:"
echo "  docker compose -f docker-compose.simple.yml up -d"
echo ""
echo "The main issue is MCP Gateway needs Docker socket access."
echo "Once core services are working, we can debug MCP Gateway separately."
EOF
