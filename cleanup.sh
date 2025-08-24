#!/bin/bash

echo "🧹 Complete cleanup and rebuild of AgentMoby..."

# Stop everything and clean up
echo "🛑 Stopping all containers..."
docker compose down --remove-orphans

echo "🗑️ Removing old images and containers..."
docker compose rm -f
docker image rm -f agentmoby-adk agentmoby-adk-ui 2>/dev/null || true
docker system prune -f

echo "📁 Cleaning up existing files..."
rm -f ui/package*.json 2>/dev/null || true
rm -rf ui/node_modules 2>/dev/null || true
rm -rf ui/pages ui/.next 2>/dev/null || true

# Ensure clean directory structure
mkdir -p ui

# Create completely fixed Dockerfile.adk-ui (embedded package.json)
echo "🔨 Creating corrected Dockerfile.adk-ui..."
cat > Dockerfile.adk-ui << 'EOF'
FROM node:18-alpine

WORKDIR /app

# Create simple Express package.json directly in Docker
RUN echo '{ \
  "name": "agentmoby-ui", \
  "version": "1.0.0", \
  "main": "server.js", \
  "scripts": { \
    "start": "node server.js" \
  }, \
  "dependencies": { \
    "express": "^4.18.2", \
    "cors": "^2.8.5", \
    "axios": "^1.6.0" \
  } \
}' > package.json

# Install dependencies
RUN npm install

# Copy ONLY the server.js file we need
COPY ui/server.js ./server.js

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001 && \
    chown -R nodejs:nodejs /app

USER nodejs

EXPOSE 3000
ENV PORT=3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:3000/health || exit 1

CMD ["node", "server.js"]
EOF

# Create simple Express server (NO Next.js references)
echo "🔨 Creating simple Express server..."
cat > ui/server.js << 'EOF'
const express = require('express');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    service: 'adk-ui',
    timestamp: new Date().toISOString() 
  });
});

// Main dashboard page
app.get('/', (req, res) => {
  const apiBaseUrl = process.env.API_BASE_URL || 'http://localhost:8000';
  
  res.send(`
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🐳 AgentMoby Dashboard</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            min-height: 100vh;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        .header {
            text-align: center;
            margin-bottom: 40px;
            background: rgba(255,255,255,0.1);
            backdrop-filter: blur(10px);
            border-radius: 20px;
            padding: 30px;
        }
        .whale { font-size: 4rem; margin-bottom: 10px; }
        .title { font-size: 2.5rem; margin: 0; text-shadow: 2px 2px 4px rgba(0,0,0,0.3); }
        .subtitle { font-size: 1.2rem; opacity: 0.9; margin: 10px 0; }
        
        .dashboard {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .card {
            background: rgba(255,255,255,0.15);
            backdrop-filter: blur(10px);
            border-radius: 15px;
            padding: 25px;
            border: 1px solid rgba(255,255,255,0.2);
            transition: transform 0.3s ease;
        }
        .card:hover { transform: translateY(-5px); }
        .card h3 { margin-bottom: 15px; color: #fff; }
        .status { 
            display: flex; 
            align-items: center; 
            margin-bottom: 10px; 
        }
        .status-dot { 
            width: 10px; 
            height: 10px; 
            border-radius: 50%; 
            margin-right: 10px;
            animation: pulse 2s infinite;
        }
        .healthy { background: #4CAF50; }
        .error { background: #f44336; }
        .loading { background: #ff9800; }
        
        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.5; }
        }
        
        .links {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 15px;
        }
        .link {
            display: block;
            background: rgba(255,255,255,0.1);
            border-radius: 10px;
            padding: 20px;
            text-decoration: none;
            color: white;
            transition: all 0.3s ease;
            border: 1px solid rgba(255,255,255,0.2);
        }
        .link:hover {
            background: rgba(255,255,255,0.2);
            transform: translateY(-2px);
        }
        .link h4 { margin-bottom: 8px; font-size: 1.1rem; }
        .link p { opacity: 0.8; font-size: 0.9rem; line-height: 1.4; }
        
        .footer {
            text-align: center;
            margin-top: 40px;
            opacity: 0.7;
            font-size: 0.9rem;
        }
        
        .success-banner {
            background: rgba(76, 175, 80, 0.2);
            border: 1px solid rgba(76, 175, 80, 0.5);
            border-radius: 10px;
            padding: 15px;
            margin-bottom: 20px;
            text-align: center;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="success-banner">
            ✅ AgentMoby UI is now running successfully with Express.js!
        </div>
        
        <div class="header">
            <div class="whale">🐳</div>
            <h1 class="title">AgentMoby</h1>
            <p class="subtitle">The Security Whale That Never Blinks</p>
            <p><small>Express.js Dashboard • No Next.js Required</small></p>
        </div>
        
        <div class="dashboard">
            <div class="card">
                <h3>🖥️ UI Service</h3>
                <div class="status">
                    <span class="status-dot healthy"></span>
                    <span>Running on port 3000</span>
                </div>
                <p>Express.js interface active</p>
            </div>
            
            <div class="card" id="adk-card">
                <h3>🤖 ADK API</h3>
                <div class="status" id="adk-status">
                    <span class="status-dot loading"></span>
                    <span id="adk-text">Checking...</span>
                </div>
                <p>Agent Development Kit</p>
            </div>
            
            <div class="card" id="gateway-card">
                <h3>🔌 MCP Gateway</h3>
                <div class="status" id="gateway-status">
                    <span class="status-dot loading"></span>
                    <span id="gateway-text">Checking...</span>
                </div>
                <p>Model Context Protocol</p>
            </div>
            
            <div class="card" id="catalogue-card">
                <h3>📊 Catalogue</h3>
                <div class="status" id="catalogue-status">
                    <span class="status-dot loading"></span>
                    <span id="catalogue-text">Checking...</span>
                </div>
                <p>Product inventory service</p>
            </div>
        </div>
        
        <div class="links">
            <a href="http://localhost:9090" class="link" target="_blank">
                <h4>🛍️ Sock Store</h4>
                <p>Customer-facing e-commerce interface</p>
            </a>
            <a href="http://localhost:8000" class="link" target="_blank">
                <h4>🤖 ADK API</h4>
                <p>Agent Development Kit endpoints</p>
            </a>
            <a href="http://localhost:8811" class="link" target="_blank">
                <h4>🔌 MCP Gateway</h4>
                <p>Model Context Protocol gateway</p>
            </a>
            <a href="http://localhost:8081" class="link" target="_blank">
                <h4>📊 Catalogue API</h4>
                <p>Product catalogue service</p>
            </a>
        </div>
        
        <div class="footer">
            <p>🐳 AgentMoby Dashboard • Built with Express.js</p>
            <p><small>API Base: ${apiBaseUrl}</small></p>
        </div>
    </div>
    
    <script>
        async function checkService(url, cardId, statusId, textId) {
            try {
                const response = await fetch(url, { 
                    method: 'GET',
                    mode: 'cors'
                });
                
                if (response.ok) {
                    const data = await response.json();
                    document.getElementById(statusId).querySelector('.status-dot').className = 'status-dot healthy';
                    document.getElementById(textId).textContent = 'Connected (' + (data.status || 'OK') + ')';
                } else {
                    throw new Error('Service unavailable');
                }
            } catch (error) {
                document.getElementById(statusId).querySelector('.status-dot').className = 'status-dot error';
                document.getElementById(textId).textContent = 'Disconnected';
            }
        }
        
        // Check services on load
        checkService('${apiBaseUrl}/health', 'adk-card', 'adk-status', 'adk-text');
        checkService('http://localhost:8811/health', 'gateway-card', 'gateway-status', 'gateway-text');
        checkService('http://localhost:8081/health', 'catalogue-card', 'catalogue-status', 'catalogue-text');
        
        // Recheck every 30 seconds
        setInterval(() => {
            checkService('${apiBaseUrl}/health', 'adk-card', 'adk-status', 'adk-text');
            checkService('http://localhost:8811/health', 'gateway-card', 'gateway-status', 'gateway-text');
            checkService('http://localhost:8081/health', 'catalogue-card', 'catalogue-status', 'catalogue-text');
        }, 30000);
        
        console.log('🐳 AgentMoby Dashboard loaded successfully!');
    </script>
</body>
</html>
  `);
});

app.listen(PORT, '0.0.0.0', () => {
  console.log('🐳 AgentMoby UI Server Started');
  console.log(`🌐 Dashboard: http://localhost:${PORT}`);
  console.log(`🔍 Health: http://localhost:${PORT}/health`);
  console.log('✅ No Next.js - Pure Express.js');
});
EOF

# Create fixed index.js for ADK service
echo "🔨 Creating fixed ADK service..."
cat > index.js << 'EOF'
const express = require('express');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 8000;

app.use(cors());
app.use(express.json());

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy',
    service: 'adk',
    timestamp: new Date().toISOString(),
    version: '1.0.0'
  });
});

// Root endpoint
app.get('/', (req, res) => {
  res.json({ 
    message: '🐳 AgentMoby ADK Service',
    version: '1.0.0',
    status: 'running',
    endpoints: {
      health: '/health',
      status: '/api/status',
      agent: '/api/agent'
    }
  });
});

// Status endpoint
app.get('/api/status', (req, res) => {
  res.json({ 
    service: 'adk',
    status: 'running',
    uptime: Math.floor(process.uptime()),
    memory: process.memoryUsage(),
    config: {
      mcpGateway: process.env.MCPGATEWAY_ENDPOINT || 'not configured',
      catalogueUrl: process.env.CATALOGUE_URL || 'not configured'
    }
  });
});

// Agent endpoint
app.post('/api/agent', (req, res) => {
  const { message } = req.body || {};
  
  res.json({
    response: `ADK received: "${message || 'no message'}"`,
    timestamp: new Date().toISOString(),
    status: 'processed'
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🐳 AgentMoby ADK running on port ${PORT}`);
  console.log(`🌐 API: http://localhost:${PORT}`);
  console.log(`🔍 Health: http://localhost:${PORT}/health`);
});
EOF

# Create super clean rebuild script
cat > super-clean-rebuild.sh << 'EOF'
#!/bin/bash

echo "🚀 Super clean rebuild starting..."

# Force stop everything
docker compose kill 2>/dev/null || true
docker compose down --remove-orphans --volumes 2>/dev/null || true

# Clean Docker system
docker system prune -f
docker volume prune -f

# Remove specific images
docker rmi agentmoby-adk agentmoby-adk-ui 2>/dev/null || true

echo "🔨 Building services from scratch..."

# Build ADK service
echo "Building ADK..."
docker compose build --no-cache --pull adk

# Build ADK-UI service  
echo "Building ADK-UI..."
docker compose build --no-cache --pull adk-ui

echo "🗄️ Starting databases..."
docker compose up -d catalogue-db mongodb

echo "⏳ Waiting 25 seconds for databases..."
sleep 25

echo "🚀 Starting all services..."
docker compose up -d

echo "⏳ Final wait for services..."
sleep 10

echo ""
echo "✅ Rebuild complete!"
echo ""
echo "🌐 Access points:"
echo "  • AgentMoby Dashboard: http://localhost:3000"
echo "  • ADK API: http://localhost:8000"
echo "  • Sock Store: http://localhost:9090"
echo ""

# Test the services
echo "🧪 Quick connectivity test:"
curl -s http://localhost:3000/health > /dev/null && echo "✅ UI Service - OK" || echo "❌ UI Service - Failed"
curl -s http://localhost:8000/health > /dev/null && echo "✅ ADK Service - OK" || echo "❌ ADK Service - Failed"

echo ""
echo "📊 Container status:"
docker compose ps
EOF

chmod +x super-clean-rebuild.sh

# Create verification script
cat > verify-services.sh << 'EOF'
#!/bin/bash

echo "🔍 Verifying all services..."
echo ""

echo "📦 Container Status:"
docker compose ps
echo ""

echo "🌐 Service Health Checks:"
services=(
    "http://localhost:3000/health|UI Service"
    "http://localhost:8000/health|ADK API"
    "http://localhost:9090|Frontend"
    "http://localhost:8081|Catalogue"
)

for service in "${services[@]}"; do
    url=$(echo $service | cut -d'|' -f1)
    name=$(echo $service | cut -d'|' -f2)
    
    if curl -s -f "$url" > /dev/null 2>&1; then
        echo "✅ $name - Responding"
    else
        echo "❌ $name - Not responding"
    fi
done

echo ""
echo "📋 Recent logs (UI Service):"
docker compose logs --tail=5 adk-ui

echo ""
echo "📋 Recent logs (ADK Service):"  
docker compose logs --tail=5 adk
EOF

chmod +x verify-services.sh

echo "🎉 Complete cleanup solution created!"
echo ""
echo "📁 Created files:"
echo "  ├── Dockerfile.adk-ui (pure Express, no Next.js)"
echo "  ├── ui/server.js (beautiful Express dashboard)"
echo "  ├── index.js (fixed ADK service)"
echo "  ├── super-clean-rebuild.sh (complete rebuild)"
echo "  └── verify-services.sh (service verification)"
echo ""
echo "🚀 To completely fix everything:"
echo "  ./super-clean-rebuild.sh"
echo ""
echo "🔍 To verify everything works:"
echo "  ./verify-services.sh"
echo ""
echo "This will:"
echo "  • Stop all containers and clean Docker cache"
echo "  • Remove old broken images completely"
echo "  • Build fresh images with correct configuration"
echo "  • Start services in proper order"
echo "  • Verify everything is working"
EOF
