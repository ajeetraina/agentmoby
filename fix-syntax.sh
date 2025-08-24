#!/bin/bash

echo "🔧 Fixing JavaScript syntax errors and Next.js issues..."

# Fix the index.js file with proper JavaScript syntax
cat > index.js << 'EOF'
const express = require('express');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 8000;

app.use(cors());
app.use(express.json());

// Health check endpoint
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
    endpoints: {
      health: '/health',
      api: '/api',
      status: '/api/status'
    },
    environment: {
      mcpGateway: process.env.MCPGATEWAY_ENDPOINT || 'not configured',
      catalogueUrl: process.env.CATALOGUE_URL || 'not configured',
      openaiBaseUrl: process.env.OPENAI_BASE_URL || 'not configured'
    }
  });
});

// Status endpoint
app.get('/api/status', (req, res) => {
  res.json({ 
    service: 'adk',
    status: 'running',
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    environment: {
      mcpGateway: process.env.MCPGATEWAY_ENDPOINT,
      catalogueUrl: process.env.CATALOGUE_URL,
      openaiBaseUrl: process.env.OPENAI_BASE_URL,
      aiModel: process.env.AI_DEFAULT_MODEL
    }
  });
});

// Agent endpoint (placeholder)
app.post('/api/agent', (req, res) => {
  const { message, context } = req.body;
  
  res.json({
    response: `ADK processed: "${message}"`,
    timestamp: new Date().toISOString(),
    context: context || {},
    status: 'processed'
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🐳 AgentMoby ADK Service running on port ${PORT}`);
  console.log(`🌐 Health check: http://localhost:${PORT}/health`);
  console.log(`📊 Status: http://localhost:${PORT}/api/status`);
});
EOF

# Create corrected Dockerfile.adk-ui (fully Express-based, no Next.js)
cat > Dockerfile.adk-ui << 'EOF'
FROM node:18-alpine

WORKDIR /app

# Create package.json for simple Express app (NO Next.js)
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

# Copy application code
COPY ui/ ./

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

CMD ["npm", "start"]
EOF

# Make sure the ui/server.js file is correct and doesn't reference Next.js
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

app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    service: 'adk-ui-api',
    timestamp: new Date().toISOString() 
  });
});

// Main page
app.get('/', (req, res) => {
  const apiBaseUrl = process.env.API_BASE_URL || 'http://localhost:8000';
  
  res.send(`
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🐳 AgentMoby</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            margin: 0;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            min-height: 100vh;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: rgba(255,255,255,0.1);
            backdrop-filter: blur(10px);
            border-radius: 20px;
            padding: 30px;
            box-shadow: 0 8px 32px rgba(0,0,0,0.1);
        }
        .header {
            text-align: center;
            margin-bottom: 40px;
        }
        .whale { font-size: 4rem; margin-bottom: 10px; }
        .title { font-size: 2.5rem; margin: 0; text-shadow: 2px 2px 4px rgba(0,0,0,0.3); }
        .subtitle { font-size: 1.2rem; opacity: 0.9; margin: 10px 0; }
        
        .status-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin: 30px 0;
        }
        .status-card {
            background: rgba(255,255,255,0.1);
            border-radius: 15px;
            padding: 20px;
            border-left: 4px solid #4CAF50;
        }
        .status-card.error { border-left-color: #f44336; }
        .status-card h3 { margin: 0 0 10px 0; }
        .status-indicator { 
            display: inline-block;
            width: 12px;
            height: 12px;
            border-radius: 50%;
            margin-right: 8px;
        }
        .status-healthy { background: #4CAF50; }
        .status-error { background: #f44336; }
        .status-loading { background: #ff9800; animation: pulse 2s infinite; }
        
        @keyframes pulse {
            0% { opacity: 1; }
            50% { opacity: 0.5; }
            100% { opacity: 1; }
        }
        
        .links-section {
            margin-top: 40px;
        }
        .links-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 15px;
        }
        .link-card {
            background: rgba(255,255,255,0.1);
            border-radius: 10px;
            padding: 15px;
            text-decoration: none;
            color: white;
            transition: transform 0.2s, background 0.2s;
        }
        .link-card:hover {
            transform: translateY(-2px);
            background: rgba(255,255,255,0.2);
        }
        .link-card h4 { margin: 0 0 5px 0; }
        .link-card p { margin: 0; opacity: 0.8; font-size: 0.9rem; }
        
        .footer {
            text-align: center;
            margin-top: 40px;
            opacity: 0.7;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="whale">🐳</div>
            <h1 class="title">AgentMoby</h1>
            <p class="subtitle">The Security Whale That Never Blinks</p>
        </div>
        
        <div class="status-grid">
            <div class="status-card">
                <h3><span class="status-indicator status-healthy"></span>UI Service</h3>
                <p>Agent interface running successfully</p>
                <small>Port: 3000</small>
            </div>
            
            <div class="status-card" id="api-status">
                <h3><span class="status-indicator status-loading"></span>ADK API</h3>
                <p id="api-message">Checking connection...</p>
                <small>Port: 8000</small>
            </div>
            
            <div class="status-card" id="gateway-status">
                <h3><span class="status-indicator status-loading"></span>MCP Gateway</h3>
                <p id="gateway-message">Checking connection...</p>
                <small>Port: 8811</small>
            </div>
            
            <div class="status-card" id="catalogue-status">
                <h3><span class="status-indicator status-loading"></span>Catalogue</h3>
                <p id="catalogue-message">Checking connection...</p>
                <small>Port: 8081</small>
            </div>
        </div>
        
        <div class="links-section">
            <h2>🔗 Quick Access</h2>
            <div class="links-grid">
                <a href="http://localhost:9090" class="link-card" target="_blank">
                    <h4>🛍️ Sock Store Frontend</h4>
                    <p>Customer-facing e-commerce interface</p>
                </a>
                
                <a href="http://localhost:8000" class="link-card" target="_blank">
                    <h4>🤖 ADK API</h4>
                    <p>Agent Development Kit endpoints</p>
                </a>
                
                <a href="http://localhost:8811" class="link-card" target="_blank">
                    <h4>🔌 MCP Gateway</h4>
                    <p>Model Context Protocol gateway</p>
                </a>
                
                <a href="http://localhost:8081" class="link-card" target="_blank">
                    <h4>📊 Catalogue Service</h4>
                    <p>Product catalogue and inventory</p>
                </a>
            </div>
        </div>
        
        <div class="footer">
            <p>🐳 AgentMoby - Securing AI agents, one container at a time</p>
            <p><small>API Base: ${apiBaseUrl}</small></p>
        </div>
    </div>
    
    <script>
        // Check service health
        async function checkService(url, statusElementId, messageElementId, serviceName) {
            try {
                const response = await fetch(url);
                const data = await response.json();
                
                const statusEl = document.getElementById(statusElementId);
                const messageEl = document.getElementById(messageElementId);
                const indicator = statusEl.querySelector('.status-indicator');
                
                indicator.className = 'status-indicator status-healthy';
                messageEl.textContent = serviceName + ' is running (' + data.status + ')';
                statusEl.className = 'status-card';
            } catch (error) {
                const statusEl = document.getElementById(statusElementId);
                const messageEl = document.getElementById(messageElementId);
                const indicator = statusEl.querySelector('.status-indicator');
                
                indicator.className = 'status-indicator status-error';
                messageEl.textContent = serviceName + ' unavailable';
                statusEl.className = 'status-card error';
            }
        }
        
        // Check all services
        checkService('${apiBaseUrl}/health', 'api-status', 'api-message', 'ADK API');
        checkService('http://localhost:8811/health', 'gateway-status', 'gateway-message', 'MCP Gateway');
        checkService('http://localhost:8081/health', 'catalogue-status', 'catalogue-message', 'Catalogue');
        
        // Refresh status every 30 seconds
        setInterval(() => {
            checkService('${apiBaseUrl}/health', 'api-status', 'api-message', 'ADK API');
            checkService('http://localhost:8811/health', 'gateway-status', 'gateway-message', 'MCP Gateway');
            checkService('http://localhost:8081/health', 'catalogue-status', 'catalogue-message', 'Catalogue');
        }, 30000);
    </script>
</body>
</html>
  `);
});

// API endpoint for agent interactions
app.post('/api/agent', async (req, res) => {
  try {
    const { message } = req.body;
    
    // This would integrate with your actual agent logic
    res.json({
      response: `Agent received: "${message}". This is a placeholder response.`,
      timestamp: new Date().toISOString(),
      status: 'success'
    });
  } catch (error) {
    res.status(500).json({
      error: 'Agent processing failed',
      message: error.message
    });
  }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🐳 AgentMoby UI running on port ${PORT}`);
  console.log(`🌐 Access at: http://localhost:${PORT}`);
});
EOF

# Clean rebuild script
cat > fix-and-rebuild.sh << 'EOF'
#!/bin/bash

echo "🔧 Fixing syntax issues and rebuilding..."

# Stop everything
docker compose down

# Remove old images to force rebuild
docker compose rm -f adk adk-ui
docker image rm agentmoby-adk agentmoby-adk-ui 2>/dev/null || true

# Rebuild with no cache
echo "🔨 Building ADK service..."
docker compose build --no-cache adk

echo "🔨 Building ADK UI service..."
docker compose build --no-cache adk-ui

# Start databases first
echo "🗄️ Starting databases..."
docker compose up -d catalogue-db mongodb

echo "⏳ Waiting for databases to initialize..."
sleep 20

# Start other services
echo "🚀 Starting all services..."
docker compose up -d

echo "⏳ Waiting for services to be ready..."
sleep 15

echo "✅ Services started!"
echo ""
echo "🌐 Access points:"
echo "  • AgentMoby UI: http://localhost:3000"
echo "  • Sock Store:   http://localhost:9090"
echo "  • ADK API:      http://localhost:8000"
echo "  • Catalogue:    http://localhost:8081"

echo ""
echo "📊 Service Status:"
docker compose ps

echo ""
echo "🔍 Test the services:"
echo "  curl http://localhost:3000/health"
echo "  curl http://localhost:8000/health"
EOF

chmod +x fix-and-rebuild.sh

# Quick syntax check script
cat > test-syntax.sh << 'EOF'
#!/bin/bash
echo "🧪 Testing JavaScript syntax..."

echo "Testing index.js:"
node -c index.js && echo "✅ index.js syntax OK" || echo "❌ index.js has syntax errors"

echo "Testing ui/server.js:"
node -c ui/server.js && echo "✅ ui/server.js syntax OK" || echo "❌ ui/server.js has syntax errors"

echo "✅ Syntax check complete"
EOF

chmod +x test-syntax.sh

echo "✅ Fixed JavaScript syntax and Next.js issues!"
echo ""
echo "📁 Fixed files:"
echo "  ├── index.js (fixed template literal syntax)"
echo "  ├── Dockerfile.adk-ui (pure Express, no Next.js)"
echo "  ├── ui/server.js (corrected Express server)"
echo "  ├── fix-and-rebuild.sh (complete rebuild script)"
echo "  └── test-syntax.sh (syntax validation)"
echo ""
echo "🚀 To fix and restart everything:"
echo "  ./test-syntax.sh    # Check syntax first"
echo "  ./fix-and-rebuild.sh # Complete rebuild and restart"
echo ""
echo "Key fixes:"
echo "  • Fixed template literal syntax error in ADK service"
echo "  • Completely removed Next.js from UI service"
echo "  • Used pure Express for both services"
echo "  • Proper JavaScript string handling"
EOF
