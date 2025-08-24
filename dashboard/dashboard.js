const express = require('express');
const cors = require('cors');
const WebSocket = require('ws');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    service: 'agentmoby-security-dashboard',
    timestamp: new Date().toISOString(),
    version: '1.0.0'
  });
});

// Main AgentMoby Security Dashboard
app.get('/', (req, res) => {
  const apiBaseUrl = process.env.API_BASE_URL || 'http://localhost:8000';
  const mcpGatewayUrl = process.env.MCP_GATEWAY_URL || 'http://localhost:8811';
  
  res.send(`
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🐳 AgentMoby - The Security Whale That Never Blinks</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%);
            color: white;
            min-height: 100vh;
            overflow-x: hidden;
        }
        
        .container {
            max-width: 1400px;
            margin: 0 auto;
            padding: 20px;
        }
        
        .header {
            text-align: center;
            margin-bottom: 40px;
            background: rgba(255,255,255,0.1);
            backdrop-filter: blur(15px);
            border-radius: 20px;
            padding: 40px;
            border: 1px solid rgba(255,255,255,0.2);
        }
        
        .whale { font-size: 5rem; margin-bottom: 10px; animation: float 6s ease-in-out infinite; }
        @keyframes float {
            0%, 100% { transform: translateY(0px); }
            50% { transform: translateY(-10px); }
        }
        
        .title { 
            font-size: 3rem; 
            margin: 0; 
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
            background: linear-gradient(45deg, #fff, #87CEEB);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }
        
        .subtitle { 
            font-size: 1.3rem; 
            opacity: 0.9; 
            margin: 15px 0;
            text-shadow: 1px 1px 2px rgba(0,0,0,0.5);
        }
        
        .security-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
            gap: 25px;
            margin: 30px 0;
        }
        
        .security-card {
            background: rgba(255,255,255,0.12);
            backdrop-filter: blur(15px);
            border-radius: 20px;
            padding: 30px;
            border: 1px solid rgba(255,255,255,0.2);
            transition: all 0.3s ease;
            position: relative;
            overflow: hidden;
        }
        
        .security-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 20px 40px rgba(0,0,0,0.3);
        }
        
        .security-card::before {
            content: '';
            position: absolute;
            top: 0;
            left: -100%;
            width: 100%;
            height: 100%;
            background: linear-gradient(90deg, transparent, rgba(255,255,255,0.1), transparent);
            transition: left 0.5s;
        }
        
        .security-card:hover::before {
            left: 100%;
        }
        
        .card-header {
            display: flex;
            align-items: center;
            margin-bottom: 20px;
        }
        
        .card-icon {
            font-size: 2.5rem;
            margin-right: 15px;
        }
        
        .card-title {
            font-size: 1.4rem;
            font-weight: 600;
        }
        
        .threat-level {
            display: inline-block;
            padding: 5px 12px;
            border-radius: 20px;
            font-size: 0.9rem;
            font-weight: 600;
            text-transform: uppercase;
        }
        
        .threat-low { background: rgba(76, 175, 80, 0.3); }
        .threat-medium { background: rgba(255, 193, 7, 0.3); }
        .threat-high { background: rgba(244, 67, 54, 0.3); }
        
        .status-indicator {
            display: flex;
            align-items: center;
            margin: 10px 0;
        }
        
        .status-dot {
            width: 12px;
            height: 12px;
            border-radius: 50%;
            margin-right: 10px;
            animation: pulse 2s infinite;
        }
        
        .status-healthy { background: #4CAF50; }
        .status-warning { background: #FF9800; }
        .status-critical { background: #F44336; }
        
        @keyframes pulse {
            0%, 100% { opacity: 1; transform: scale(1); }
            50% { opacity: 0.7; transform: scale(1.1); }
        }
        
        .agent-controls {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin-top: 20px;
        }
        
        .control-btn {
            background: rgba(255,255,255,0.2);
            border: 1px solid rgba(255,255,255,0.3);
            color: white;
            padding: 12px 20px;
            border-radius: 10px;
            cursor: pointer;
            transition: all 0.3s ease;
            text-decoration: none;
            text-align: center;
            display: block;
        }
        
        .control-btn:hover {
            background: rgba(255,255,255,0.3);
            transform: translateY(-2px);
        }
        
        .alert-banner {
            background: linear-gradient(45deg, rgba(244, 67, 54, 0.2), rgba(156, 39, 176, 0.2));
            border: 1px solid rgba(244, 67, 54, 0.5);
            border-radius: 15px;
            padding: 20px;
            margin-bottom: 25px;
            text-align: center;
            animation: glow 2s infinite;
        }
        
        @keyframes glow {
            0%, 100% { box-shadow: 0 0 20px rgba(244, 67, 54, 0.3); }
            50% { box-shadow: 0 0 30px rgba(244, 67, 54, 0.5); }
        }
        
        .footer {
            text-align: center;
            margin-top: 50px;
            opacity: 0.8;
            font-size: 0.9rem;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="alert-banner">
            🚨 <strong>AgentMoby Security Monitor Active</strong> - The whale is watching for threats 24/7
        </div>
        
        <div class="header">
            <div class="whale">🐳</div>
            <h1 class="title">AgentMoby</h1>
            <p class="subtitle">The Security Whale That Never Blinks</p>
            <p><small>AI Agent Security Platform • Real-Time Threat Monitoring</small></p>
        </div>
        
        <div class="security-grid">
            <div class="security-card">
                <div class="card-header">
                    <div class="card-icon">🛡️</div>
                    <div>
                        <div class="card-title">Threat Detection</div>
                        <div class="threat-level threat-low">Secure</div>
                    </div>
                </div>
                <div class="status-indicator">
                    <span class="status-dot status-healthy"></span>
                    <span>All systems protected</span>
                </div>
                <p>AI-powered threat detection monitoring all agent interactions</p>
            </div>
            
            <div class="security-card" id="agent-status">
                <div class="card-header">
                    <div class="card-icon">🤖</div>
                    <div>
                        <div class="card-title">AI Agent Core</div>
                        <div id="agent-status-badge" class="threat-level threat-medium">Checking...</div>
                    </div>
                </div>
                <div class="status-indicator">
                    <span class="status-dot status-warning" id="agent-dot"></span>
                    <span id="agent-text">Connecting to agent...</span>
                </div>
                <p>Secure AI agent with OpenAI integration</p>
            </div>
            
            <div class="security-card" id="mcp-status">
                <div class="card-header">
                    <div class="card-icon">🔌</div>
                    <div>
                        <div class="card-title">MCP Gateway</div>
                        <div id="mcp-status-badge" class="threat-level threat-medium">Checking...</div>
                    </div>
                </div>
                <div class="status-indicator">
                    <span class="status-dot status-warning" id="mcp-dot"></span>
                    <span id="mcp-text">Connecting to gateway...</span>
                </div>
                <p>Secure tool access and management</p>
            </div>
            
            <div class="security-card">
                <div class="card-header">
                    <div class="card-icon">📊</div>
                    <div>
                        <div class="card-title">Security Analytics</div>
                        <div class="threat-level threat-low">Active</div>
                    </div>
                </div>
                <div class="status-indicator">
                    <span class="status-dot status-healthy"></span>
                    <span>Monitoring 24/7</span>
                </div>
                <p>Real-time analysis of agent behavior and security metrics</p>
            </div>
            
            <div class="security-card">
                <div class="card-header">
                    <div class="card-icon">🔒</div>
                    <div>
                        <div class="card-title">Access Control</div>
                        <div class="threat-level threat-low">Secured</div>
                    </div>
                </div>
                <div class="status-indicator">
                    <span class="status-dot status-healthy"></span>
                    <span>Zero-trust architecture</span>
                </div>
                <p>Container isolation and network security controls</p>
            </div>
            
            <div class="security-card">
                <div class="card-header">
                    <div class="card-icon">🌊</div>
                    <div>
                        <div class="card-title">Whale Watch</div>
                        <div class="threat-level threat-low">Vigilant</div>
                    </div>
                </div>
                <div class="status-indicator">
                    <span class="status-dot status-healthy"></span>
                    <span>Always watching</span>
                </div>
                <p>The security whale never blinks - continuous monitoring</p>
            </div>
        </div>
        
        <div class="agent-controls">
            <a href="${apiBaseUrl}" target="_blank" class="control-btn">🤖 Agent API</a>
            <a href="${mcpGatewayUrl}" target="_blank" class="control-btn">🔌 MCP Gateway</a>
            <a href="#" onclick="testAgent()" class="control-btn">🧪 Test Agent</a>
            <a href="#" onclick="viewLogs()" class="control-btn">📋 View Logs</a>
        </div>
        
        <div class="footer">
            <p>🐳 <strong>AgentMoby</strong> - Securing AI agents, one container at a time</p>
            <p><small>The Security Whale That Never Blinks • Built with Docker & AI Security Best Practices</small></p>
        </div>
    </div>
    
    <script>
        // Check agent and MCP gateway status
        async function checkStatus() {
            // Check Agent Core
            try {
                const agentResponse = await fetch('${apiBaseUrl}/health');
                if (agentResponse.ok) {
                    document.getElementById('agent-dot').className = 'status-dot status-healthy';
                    document.getElementById('agent-text').textContent = 'Agent core operational';
                    document.getElementById('agent-status-badge').className = 'threat-level threat-low';
                    document.getElementById('agent-status-badge').textContent = 'Secure';
                } else {
                    throw new Error('Agent not responding');
                }
            } catch (error) {
                document.getElementById('agent-dot').className = 'status-dot status-critical';
                document.getElementById('agent-text').textContent = 'Agent offline';
                document.getElementById('agent-status-badge').className = 'threat-level threat-high';
                document.getElementById('agent-status-badge').textContent = 'Offline';
            }
            
            // Check MCP Gateway
            try {
                const mcpResponse = await fetch('${mcpGatewayUrl}/health');
                if (mcpResponse.ok) {
                    document.getElementById('mcp-dot').className = 'status-dot status-healthy';
                    document.getElementById('mcp-text').textContent = 'Gateway operational';
                    document.getElementById('mcp-status-badge').className = 'threat-level threat-low';
                    document.getElementById('mcp-status-badge').textContent = 'Secure';
                } else {
                    throw new Error('MCP not responding');
                }
            } catch (error) {
                document.getElementById('mcp-dot').className = 'status-dot status-critical';
                document.getElementById('mcp-text').textContent = 'Gateway offline';
                document.getElementById('mcp-status-badge').className = 'threat-level threat-high';
                document.getElementById('mcp-status-badge').textContent = 'Offline';
            }
        }
        
        // Test agent functionality
        async function testAgent() {
            try {
                const response = await fetch('${apiBaseUrl}/api/agent', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        message: 'Perform a security assessment of the current AgentMoby system'
                    })
                });
                
                if (response.ok) {
                    const data = await response.json();
                    alert('🤖 Agent Response: ' + data.response);
                } else {
                    alert('❌ Agent test failed');
                }
            } catch (error) {
                alert('❌ Could not connect to agent');
            }
        }
        
        // View system logs
        function viewLogs() {
            alert('📋 Logs: Check Docker logs with: docker compose logs -f agent-core');
        }
        
        // Initialize
        checkStatus();
        setInterval(checkStatus, 30000); // Update every 30 seconds
        
        console.log('🐳 AgentMoby Security Dashboard loaded');
        console.log('🛡️ The whale is watching...');
    </script>
</body>
</html>
  `);
});

app.listen(PORT, '0.0.0.0', () => {
  console.log('🐳 AgentMoby Security Dashboard running on port', PORT);
  console.log('🛡️ The Security Whale is watching...');
  console.log('🌐 Dashboard: http://localhost:' + PORT);
});
