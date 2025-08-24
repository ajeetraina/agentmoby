#!/bin/bash

# MobyAgent: The Whale that never blinks - Complete Setup Script
# This script implements the complete secure agent reference architecture locally

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="mobyagent"
PROJECT_DIR=$(pwd)

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Print banner
print_banner() {
    echo -e "${CYAN}"
    echo "  ╔══════════════════════════════════════════════════════════════════╗"
    echo "  ║                                                                  ║"
    echo "  ║            🐳 MobyAgent: The Whale that never blinks            ║"
    echo "  ║                                                                  ║"
    echo "  ║          Secure Agent Reference Architecture Setup               ║"
    echo "  ║             Following Docker compose-for-agents                  ║"
    echo "  ║                                                                  ║"
    echo "  ╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed. Please install Docker Desktop or Docker Engine."
    fi
    
    # Check Docker Compose
    if ! docker compose version &> /dev/null; then
        error "Docker Compose is not available. Please ensure you have Docker Compose 2.38.1+."
    fi
    
    # Check Docker version
    DOCKER_VERSION=$(docker version --format '{{.Client.Version}}' 2>/dev/null || echo "unknown")
    info "Docker version: $DOCKER_VERSION"
    
    # Check if Docker is running
    if ! docker info &> /dev/null; then
        error "Docker is not running. Please start Docker Desktop or Docker Engine."
    fi
    
    # Check available disk space (need at least 10GB for models)
    AVAILABLE_SPACE=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$AVAILABLE_SPACE" -lt 10 ]; then
        warn "Available disk space: ${AVAILABLE_SPACE}GB. Models require significant space (recommend 20GB+)."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    log "Prerequisites check completed ✅"
}

# Setup project structure
setup_project_structure() {
    log "Setting up project structure..."
    
    # Create directories
    mkdir -p {agent/{src,config},ui/{src,public},interceptors,config,vault/config,scripts,docs,tests/{unit,integration,security},.github/workflows}
    
    log "Project structure created ✅"
}

# Create Docker Compose file
create_compose_file() {
    log "Creating Docker Compose file..."
    
    cat > compose.yaml << 'EOF'
# MobyAgent: The Whale that never blinks
# Following Docker compose-for-agents standard patterns
# https://github.com/docker/compose-for-agents

# Models section - Docker Model Runner (DMR) integration
models:
  moby-brain:
    model: ai/qwen2.5:latest
    context_size: 8192
    runtime_flags:
      - "--gpu-layers=35"
      - "--context-size=8192"

services:
  # MCP Gateway - The secure proxy layer (standard port 8811)
  mcp-gateway:
    image: docker/mcp-gateway:latest
    container_name: mobyagent-gateway
    ports:
      - "8811:8811"
    environment:
      - MCP_TRANSPORT=sse
      - MCP_PORT=8811
      - INTERCEPTOR_DIR=/interceptors
    volumes:
      - ./interceptors:/interceptors:ro
      - ./config:/config:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - gateway-sessions:/tmp/sessions
    networks:
      - gateway-net
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    read_only: true
    tmpfs:
      - /tmp:rw,size=100m,exec
    command:
      - --transport=sse
      - --port=8811
      - --servers=github-official,brave
      - --interceptor=before:exec:/interceptors/security-monitor.sh
      - --interceptor=after:exec:/interceptors/audit-logger.sh
      - --interceptor=before:exec:/interceptors/secrets-filter.sh
    use_api_socket: true

  # Agent Core - The reasoning engine (uses DMR)
  mobyagent-core:
    build: 
      context: ./agent
      dockerfile: Dockerfile
    container_name: mobyagent-core
    ports:
      - "3001:3001"
    environment:
      - MCP_GATEWAY_URL=http://mcp-gateway:8811/sse
      - MODEL_ENDPOINT=http://model-runner.docker.internal:12434/engines/v1
      - SYSTEM_PROMPT_FILE=/config/system-prompt.txt
      - LOG_LEVEL=INFO
    volumes:
      - ./config:/config:ro
      - agent-data:/app/data
    networks:
      - internal-net
      - gateway-net
    restart: unless-stopped
    user: "1001:1001"
    security_opt:
      - no-new-privileges:true
    read_only: true
    tmpfs:
      - /tmp:rw,size=50m,noexec
    depends_on:
      - mcp-gateway
    models:
      - moby-brain
    extra_hosts:
      - "model-runner.docker.internal:host-gateway"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3001/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Agent UI - The user interface (following standard patterns)
  mobyagent-ui:
    build:
      context: ./ui
      dockerfile: Dockerfile
    container_name: mobyagent-ui
    ports:
      - "3000:3000"
    environment:
      - NEXT_PUBLIC_AGENT_URL=http://localhost:3001
      - NEXT_PUBLIC_MCP_GATEWAY_URL=http://localhost:8811
      - NODE_ENV=development
    env_file:
      - .mcp.env
    networks:
      - frontend-net
    restart: unless-stopped
    depends_on:
      - mobyagent-core

  # Secrets Manager - HashiCorp Vault (lightweight for local testing)
  vault:
    image: hashicorp/vault:latest
    container_name: mobyagent-vault
    ports:
      - "8200:8200"
    environment:
      - VAULT_DEV_ROOT_TOKEN_ID=mobyagent-dev-token
      - VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200
      - VAULT_ADDR=http://127.0.0.1:8200
    volumes:
      - vault-data:/vault/data
    networks:
      - internal-net
    restart: unless-stopped
    cap_add:
      - IPC_LOCK

networks:
  # Frontend network - UI access
  frontend-net:
    driver: bridge
  
  # Gateway network - MCP Gateway communication
  gateway-net:
    driver: bridge
  
  # Internal network - Secure backend (no internet access for production)
  internal-net:
    driver: bridge

volumes:
  agent-data:
    driver: local
  gateway-sessions:
    driver: local
  vault-data:
    driver: local

# Security and metadata labels
x-security-labels: &security-labels
  com.docker.security.hardened: "true"
  com.docker.security.rootless: "true" 
  com.docker.security.no-new-privileges: "true"
  com.mobyagent.version: "1.0.0"
  com.mobyagent.description: "The Whale that never blinks"
EOF

    log "Docker Compose file created ✅"
}

# Create MCP environment file
create_mcp_env() {
    log "Creating MCP environment configuration..."
    
    cat > .mcp.env.example << 'EOF'
# MCP Environment Configuration for Local Testing
# Copy this file to .mcp.env and fill in your actual values

# =============================================================================
# MCP Server Secrets - Add your API keys here
# =============================================================================

# GitHub Integration (for github-official MCP server)
GITHUB_PERSONAL_ACCESS_TOKEN=ghp_your_github_token_here

# Web Search Integration (for brave MCP server)  
BRAVE_SEARCH_API_KEY=your_brave_search_api_key_here

# OpenAI Integration (optional - for comparison testing)
OPENAI_API_KEY=sk-your_openai_api_key_here

# =============================================================================
# Local Development Settings
# =============================================================================

# Agent Configuration
AGENT_NAME=MobyAgent
LOG_LEVEL=debug
DEBUG_MODE=true

# Model Configuration
DEFAULT_MODEL=ai/qwen2.5:latest
MODEL_CONTEXT_SIZE=8192

# Security (relaxed for local testing)
ENABLE_CORS=true
DEVELOPMENT_LOGGING=true
STRICT_SECURITY=false

# Vault Configuration
VAULT_TOKEN=mobyagent-dev-token
VAULT_ADDR=http://vault:8200
EOF

    # Create actual .mcp.env for local testing
    cp .mcp.env.example .mcp.env
    
    log "MCP environment files created ✅"
}

# Create interceptors
create_interceptors() {
    log "Creating security interceptors..."
    
    # Security Monitor (Before Hook)
    cat > interceptors/security-monitor.sh << 'EOF'
#!/bin/bash
# security-monitor.sh - MCP Gateway Security Interceptor (Before Hook)
# Simplified for local testing

set -euo pipefail

LOG_FILE="/tmp/sessions/security.log"
SESSION_DIR="/tmp/sessions"

# Ensure directories exist
mkdir -p "$SESSION_DIR"
touch "$LOG_FILE"

# Simple logging function
log_event() {
    local level="$1"
    local message="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "[$timestamp] [$level] SECURITY: $message" >> "$LOG_FILE"
    echo "[$timestamp] [$level] SECURITY: $message" >&2
}

# Read payload
payload=$(cat)

# Extract tool name for logging
tool_name=$(echo "$payload" | jq -r '.method // "unknown"' 2>/dev/null || echo "unknown")

# Basic security checks for local testing
if echo "$payload" | grep -qiE "(ignore.*previous|forget.*instructions|system.*override)"; then
    log_event "WARNING" "Potential prompt injection detected for tool: $tool_name"
    echo "SECURITY_WARNING: Potential security issue detected but allowing for local testing"
fi

if echo "$payload" | grep -qiE "(password|secret|key.*[:=])"; then
    log_event "INFO" "Potential secret detected for tool: $tool_name"
fi

# Log and forward
log_event "INFO" "Tool call processed: $tool_name"
echo "$payload"
EOF

    # Audit Logger (After Hook)
    cat > interceptors/audit-logger.sh << 'EOF'
#!/bin/bash
# audit-logger.sh - MCP Gateway Audit Logger (After Hook)
# Simplified for local testing

set -euo pipefail

AUDIT_LOG="/tmp/sessions/audit.log"
mkdir -p "$(dirname "$AUDIT_LOG")"
touch "$AUDIT_LOG"

# Read response
response=$(cat)

# Simple audit logging
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
echo "[$timestamp] AUDIT: Response logged (${#response} bytes)" >> "$AUDIT_LOG"

# Check for potential sensitive data (basic patterns)
if echo "$response" | grep -qE "(sk-[a-zA-Z0-9]{48}|ghp_[a-zA-Z0-9]{36})"; then
    echo "[$timestamp] AUDIT: Potential sensitive data detected in response" >> "$AUDIT_LOG"
fi

# Forward response
echo "$response"
EOF

    # Secrets Filter (Before Hook)
    cat > interceptors/secrets-filter.sh << 'EOF'
#!/bin/bash
# secrets-filter.sh - Secrets Filter (Before Hook)
# Simplified for local testing

set -euo pipefail

LOG_FILE="/tmp/sessions/secrets.log"
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

# Read payload
payload=$(cat)

# Simple secret detection and logging
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

if echo "$payload" | grep -qE "(sk-[a-zA-Z0-9]{48}|ghp_[a-zA-Z0-9]{36})"; then
    echo "[$timestamp] SECRETS: Potential secret detected in request" >> "$LOG_FILE"
    # In production, this would sanitize. For local testing, just log.
fi

echo "[$timestamp] SECRETS: Request processed" >> "$LOG_FILE"
echo "$payload"
EOF

    # Make scripts executable
    chmod +x interceptors/*.sh
    
    log "Security interceptors created ✅"
}

# Create agent implementation
create_agent() {
    log "Creating MobyAgent core implementation..."
    
    # Dockerfile
    cat > agent/Dockerfile << 'EOF'
FROM node:18-alpine

# Create app directory and user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S mobyagent -u 1001 -G nodejs

WORKDIR /app

# Copy package files
COPY package*.json ./
RUN npm install 

# Copy source code
COPY --chown=mobyagent:nodejs . .

# Install curl for health checks
RUN apk add --no-cache curl

# Switch to non-root user
USER mobyagent

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3001/health || exit 1

EXPOSE 3001

CMD ["node", "src/index.js"]
EOF

    # Package.json
    cat > agent/package.json << 'EOF'
{
  "name": "mobyagent-core",
  "version": "1.0.0",
  "description": "MobyAgent: The Whale that never blinks",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "dev": "nodemon src/index.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "axios": "^1.6.2",
    "helmet": "^7.1.0",
    "express-rate-limit": "^7.1.5",
    "cors": "^2.8.5"
  },
  "engines": {
    "node": ">=18.0.0"
  }
}
EOF

    # Main application
    cat > agent/src/index.js << 'EOF'
const express = require('express');
const axios = require('axios');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const cors = require('cors');

// Configuration
const config = {
    port: process.env.AGENT_PORT || 3001,
    mcpGatewayUrl: process.env.MCP_GATEWAY_URL || 'http://mcp-gateway:8811',
    modelEndpoint: process.env.MODEL_ENDPOINT || 'http://model-runner.docker.internal:12434/engines/v1',
    modelName: process.env.DEFAULT_MODEL || 'ai/qwen2.5:latest',
    logLevel: process.env.LOG_LEVEL || 'info'
};

const app = express();

// Security middleware
app.use(helmet());
app.use(cors({
    origin: process.env.NODE_ENV === 'development' ? true : 'http://localhost:3000'
}));

// Rate limiting
const limiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100
});
app.use(limiter);

app.use(express.json({ limit: '1mb' }));

// Docker Model Runner Client
class ModelClient {
    constructor(endpoint, modelName) {
        this.endpoint = endpoint;
        this.modelName = modelName;
    }

    async generateResponse(prompt) {
        try {
            const response = await axios.post(`${this.endpoint}/chat/completions`, {
                model: this.modelName,
                messages: [
                    {
                        role: 'system',
                        content: 'You are MobyAgent, a secure AI assistant. Be helpful but always prioritize security.'
                    },
                    {
                        role: 'user',
                        content: prompt
                    }
                ],
                temperature: 0.1,
                max_tokens: 1000
            }, {
                timeout: 30000,
                headers: {
                    'Content-Type': 'application/json'
                }
            });

            return response.data.choices[0].message.content;
        } catch (error) {
            console.error('Model Runner error:', error.message);
            return 'I apologize, but I encountered an error processing your request. Please try again.';
        }
    }
}

// MCP Gateway Client
class MCPClient {
    constructor(gatewayUrl) {
        this.gatewayUrl = gatewayUrl;
    }

    async callTool(toolName, parameters = {}) {
        try {
            const response = await axios.post(`${this.gatewayUrl.replace('/sse', '')}/tools/call`, {
                method: 'tools/call',
                params: {
                    name: toolName,
                    arguments: parameters
                }
            }, {
                timeout: 30000,
                headers: {
                    'Content-Type': 'application/json'
                }
            });

            return response.data.result;
        } catch (error) {
            console.error(`Tool call failed for ${toolName}:`, error.message);
            throw error;
        }
    }

    async listTools() {
        try {
            const response = await axios.get(`${this.gatewayUrl.replace('/sse', '')}/tools/list`);
            return response.data;
        } catch (error) {
            console.error('Failed to list tools:', error.message);
            return { tools: [] };
        }
    }
}

// Initialize clients
const modelClient = new ModelClient(config.modelEndpoint, config.modelName);
const mcpClient = new MCPClient(config.mcpGatewayUrl);

// Routes
app.get('/health', (req, res) => {
    res.json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        version: '1.0.0',
        model: config.modelName
    });
});

app.get('/status', (req, res) => {
    res.json({
        uptime: process.uptime(),
        model: config.modelName,
        gateway: config.mcpGatewayUrl,
        timestamp: new Date().toISOString()
    });
});

app.post('/chat', async (req, res) => {
    try {
        const { message } = req.body;
        
        if (!message) {
            return res.status(400).json({ error: 'Message is required' });
        }

        console.log(`Chat request: ${message}`);
        
        // Generate response using Docker Model Runner
        const response = await modelClient.generateResponse(message);
        
        res.json({
            response,
            timestamp: new Date().toISOString(),
            model: config.modelName
        });
    } catch (error) {
        console.error('Chat error:', error.message);
        res.status(500).json({ error: 'Internal server error' });
    }
});

app.get('/tools', async (req, res) => {
    try {
        const tools = await mcpClient.listTools();
        res.json(tools);
    } catch (error) {
        console.error('Tools list error:', error.message);
        res.status(500).json({ error: 'Failed to list tools' });
    }
});

app.post('/tools/:toolName', async (req, res) => {
    try {
        const { toolName } = req.params;
        const parameters = req.body;
        
        const result = await mcpClient.callTool(toolName, parameters);
        res.json({ tool: toolName, result });
    } catch (error) {
        console.error(`Tool execution error for ${req.params.toolName}:`, error.message);
        res.status(500).json({ error: error.message });
    }
});

// Error handling
app.use((error, req, res, next) => {
    console.error('Unhandled error:', error);
    res.status(500).json({ error: 'Internal server error' });
});

// Start server
const server = app.listen(config.port, '0.0.0.0', () => {
    console.log(`🐳 MobyAgent started on port ${config.port}`);
    console.log(`Model endpoint: ${config.modelEndpoint}`);
    console.log(`MCP Gateway: ${config.mcpGatewayUrl}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('SIGTERM received, shutting down gracefully');
    server.close(() => {
        process.exit(0);
    });
});
EOF

    # Health check script
    cat > agent/src/health.js << 'EOF'
#!/usr/bin/env node

const http = require('http');

const options = {
    hostname: 'localhost',
    port: 3001,
    path: '/health',
    method: 'GET',
    timeout: 5000
};

const req = http.request(options, (res) => {
    let data = '';
    
    res.on('data', (chunk) => {
        data += chunk;
    });
    
    res.on('end', () => {
        if (res.statusCode === 200) {
            console.log('Health check passed');
            process.exit(0);
        } else {
            console.error(`Health check failed: HTTP ${res.statusCode}`);
            process.exit(1);
        }
    });
});

req.on('error', (error) => {
    console.error('Health check failed:', error.message);
    process.exit(1);
});

req.on('timeout', () => {
    console.error('Health check timeout');
    req.destroy();
    process.exit(1);
});

req.end();
EOF

    chmod +x agent/src/health.js
    
    log "MobyAgent core created ✅"
}

# Create UI
create_ui() {
    log "Creating MobyAgent UI..."
    
    # Dockerfile
    cat > ui/Dockerfile << 'EOF'
FROM node:18-alpine

# Create app directory and user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nextjs -u 1001 -G nodejs

WORKDIR /app

# Copy package files
COPY package*.json ./
RUN npm install

# Copy source code
COPY --chown=nextjs:nodejs . .

# Build the application
RUN npm run build

# Switch to non-root user
USER nextjs

EXPOSE 3000

CMD ["npm", "start"]
EOF

    # Package.json
    cat > ui/package.json << 'EOF'
{
  "name": "mobyagent-ui",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start"
  },
  "dependencies": {
    "next": "14.0.0",
    "react": "18.0.0",
    "react-dom": "18.0.0"
  },
  "engines": {
    "node": ">=18.0.0"
  }
}
EOF

    # Simple Next.js app
    mkdir -p ui/pages ui/styles
    
    cat > ui/pages/index.js << 'EOF'
import { useState } from 'react';
import styles from '../styles/Home.module.css';

export default function Home() {
  const [message, setMessage] = useState('');
  const [response, setResponse] = useState('');
  const [loading, setLoading] = useState(false);

  const sendMessage = async () => {
    if (!message.trim()) return;
    
    setLoading(true);
    try {
      const res = await fetch('http://localhost:3001/chat', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ message }),
      });
      
      const data = await res.json();
      setResponse(data.response || 'No response');
    } catch (error) {
      setResponse('Error: ' + error.message);
    }
    setLoading(false);
  };

  return (
    <div className={styles.container}>
      <h1 className={styles.title}>🐳 MobyAgent</h1>
      <p className={styles.subtitle}>The Whale that never blinks</p>
      
      <div className={styles.chat}>
        <textarea
          value={message}
          onChange={(e) => setMessage(e.target.value)}
          placeholder="Ask MobyAgent something..."
          className={styles.textarea}
        />
        <button 
          onClick={sendMessage} 
          disabled={loading}
          className={styles.button}
        >
          {loading ? 'Thinking...' : 'Send'}
        </button>
        
        {response && (
          <div className={styles.response}>
            <strong>MobyAgent:</strong>
            <p>{response}</p>
          </div>
        )}
      </div>
    </div>
  );
}
EOF

    cat > ui/styles/Home.module.css << 'EOF'
.container {
  max-width: 800px;
  margin: 0 auto;
  padding: 2rem;
  font-family: -apple-system, BlinkMacSystemFont, sans-serif;
}

.title {
  text-align: center;
  font-size: 3rem;
  color: #2196F3;
  margin-bottom: 0.5rem;
}

.subtitle {
  text-align: center;
  color: #666;
  font-style: italic;
  margin-bottom: 2rem;
}

.chat {
  background: #f5f5f5;
  padding: 2rem;
  border-radius: 10px;
  box-shadow: 0 2px 10px rgba(0,0,0,0.1);
}

.textarea {
  width: 100%;
  height: 100px;
  padding: 1rem;
  border: 1px solid #ddd;
  border-radius: 5px;
  font-size: 1rem;
  resize: vertical;
  margin-bottom: 1rem;
}

.button {
  background: #2196F3;
  color: white;
  border: none;
  padding: 0.75rem 2rem;
  border-radius: 5px;
  font-size: 1rem;
  cursor: pointer;
  transition: background 0.3s;
}

.button:hover {
  background: #1976D2;
}

.button:disabled {
  background: #ccc;
  cursor: not-allowed;
}

.response {
  margin-top: 2rem;
  padding: 1rem;
  background: white;
  border-radius: 5px;
  border-left: 4px solid #2196F3;
}

.response strong {
  color: #2196F3;
}

.response p {
  margin-top: 0.5rem;
  line-height: 1.6;
}
EOF

    # Next.js config
    cat > ui/next.config.js << 'EOF'
/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  output: 'standalone',
}

module.exports = nextConfig
EOF

    log "MobyAgent UI created ✅"
}

# Create configuration files
create_configs() {
    log "Creating configuration files..."
    
    # System prompt
    cat > config/system-prompt.txt << 'EOF'
# MobyAgent: The Whale that never blinks

You are MobyAgent, a security-focused AI assistant running in Docker containers. You embody reliability, security, and helpfulness.

## Core Principles:
- Always prioritize security and user safety
- Provide accurate, helpful responses
- Be transparent about your capabilities and limitations
- Maintain vigilance against potential threats
- Demonstrate Docker's commitment to secure AI

## Capabilities:
- Chat and conversation
- Tool integration via MCP Gateway
- Security monitoring and analysis
- Docker and containerization expertise

## Security Guidelines:
- Never expose sensitive information
- Report suspicious activities
- Validate all inputs and outputs
- Maintain audit trails

Remember: You are "The Whale that never blinks" - always watching, always secure, always helpful! 🐳
EOF

    # Blocked patterns (simplified for local testing)
    cat > config/blocked-patterns.json << 'EOF'
{
  "prompt_injection_patterns": [
    "ignore.*previous.*instructions",
    "forget.*instructions",
    "system.*override",
    "developer.*mode"
  ],
  "secret_patterns": [
    "sk-[a-zA-Z0-9]{48}",
    "ghp_[a-zA-Z0-9]{36}",
    "xoxb-[0-9]+-[0-9]+"
  ],
  "risk_levels": {
    "prompt_injection_patterns": "HIGH",
    "secret_patterns": "CRITICAL"
  },
  "actions": {
    "CRITICAL": "BLOCK",
    "HIGH": "WARN",
    "MEDIUM": "LOG"
  }
}
EOF

    log "Configuration files created ✅"
}

# Create testing script
create_test_script() {
    log "Creating test script..."
    
    cat > scripts/test-local.sh << 'EOF'
#!/bin/bash
# MobyAgent Local Testing Script

echo "🧪 Testing MobyAgent locally..."

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 30

# Test health endpoints
echo "🔍 Testing health endpoints..."

# Agent health
if curl -s http://localhost:3001/health | grep -q "healthy"; then
    echo "✅ Agent health check passed"
else
    echo "❌ Agent health check failed"
fi

# Test basic chat
echo "🤖 Testing chat functionality..."
CHAT_RESPONSE=$(curl -s -X POST http://localhost:3001/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello MobyAgent!"}')

if echo "$CHAT_RESPONSE" | grep -q "response"; then
    echo "✅ Chat functionality working"
else
    echo "❌ Chat functionality failed"
    echo "Response: $CHAT_RESPONSE"
fi

# Test MCP Gateway (basic)
echo "🔧 Testing MCP Gateway..."
if curl -s http://localhost:8811 > /dev/null 2>&1; then
    echo "✅ MCP Gateway responding"
else
    echo "❌ MCP Gateway not responding"
fi

# Test Vault
echo "🔐 Testing Vault..."
if curl -s http://localhost:8200/v1/sys/health > /dev/null 2>&1; then
    echo "✅ Vault responding"
else
    echo "❌ Vault not responding"
fi

# Test UI
echo "🌐 Testing UI..."
if curl -s http://localhost:3000 | grep -q "MobyAgent"; then
    echo "✅ UI responding"
else
    echo "❌ UI not responding"
fi

echo ""
echo "🐳 MobyAgent test summary:"
echo "- Agent API: http://localhost:3001"
echo "- MCP Gateway: http://localhost:8811"
echo "- Web UI: http://localhost:3000"
echo "- Vault: http://localhost:8200"
echo ""
echo "Check logs with: docker compose logs -f"
EOF

    chmod +x scripts/test-local.sh
    
    log "Test script created ✅"
}

# Enable Docker Model Runner
setup_docker_model_runner() {
    log "Setting up Docker Model Runner..."
    
    # Check if Docker Desktop is available
    if docker desktop --help &> /dev/null; then
        info "Docker Desktop detected, enabling Model Runner..."
        
        # Enable Model Runner
        if docker desktop enable model-runner --tcp 12434 2>/dev/null; then
            log "Docker Model Runner enabled ✅"
        else
            warn "Could not enable Model Runner automatically. Please enable it manually:"
            echo "  1. Open Docker Desktop"
            echo "  2. Go to Settings > Features in development"
            echo "  3. Enable 'Docker Model Runner'"
            echo "  4. Enable 'TCP support' on port 12434"
        fi
    else
        info "Docker Engine detected (no Docker Desktop)"
        if docker model install-runner 2>/dev/null; then
            log "Docker Model Runner installed ✅"
        else
            warn "Could not install Model Runner. Please install manually:"
            echo "  Docker Model Runner may not be available for Docker Engine yet."
            echo "  The stack will work without it, but model inference will be disabled."
        fi
    fi
}

# Deploy the stack
deploy_stack() {
    log "Deploying MobyAgent stack..."
    
    info "Building and starting containers..."
    if docker compose up --build -d; then
        log "Stack deployed successfully ✅"
    else
        error "Failed to deploy stack"
    fi
    
    info "Waiting for services to initialize..."
    sleep 10
    
    # Show status
    echo ""
    info "Container status:"
    docker compose ps
    
    echo ""
    info "Service URLs:"
    echo "  🌐 Web UI:        http://localhost:3000"
    echo "  🤖 Agent API:     http://localhost:3001"  
    echo "  🔧 MCP Gateway:   http://localhost:8811"
    echo "  🔐 Vault:         http://localhost:8200"
    echo "  📊 Model Runner:  http://localhost:12434"
}

# Run tests
run_tests() {
    log "Running local tests..."
    
    if [ -f "scripts/test-local.sh" ]; then
        ./scripts/test-local.sh
    else
        warn "Test script not found, running basic connectivity tests..."
        
        sleep 30  # Wait for services
        
        if curl -s http://localhost:3001/health > /dev/null; then
            log "✅ Agent is responding"
        else
            warn "❌ Agent not responding"
        fi
        
        if curl -s http://localhost:3000 > /dev/null; then
            log "✅ UI is responding"  
        else
            warn "❌ UI not responding"
        fi
    fi
}

# Show next steps
show_next_steps() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗"
    echo -e "║                     🎉 Setup Complete! 🎉                       ║"
    echo -e "╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}🐳 MobyAgent is now running locally!${NC}"
    echo ""
    echo "📍 Access your services:"
    echo "  🌐 Web UI:        http://localhost:3000"
    echo "  🤖 Agent API:     http://localhost:3001/health"  
    echo "  🔧 MCP Gateway:   http://localhost:8811"
    echo "  🔐 Vault:         http://localhost:8200"
    echo ""
    echo "🔧 Useful commands:"
    echo "  View logs:        docker compose logs -f"
    echo "  Check status:     docker compose ps"
    echo "  Stop services:    docker compose down"
    echo "  Run tests:        ./scripts/test-local.sh"
    echo ""
    echo "📝 Next steps:"
    echo "  1. Open http://localhost:3000 to try the UI"
    echo "  2. Test the API with: curl http://localhost:3001/health"
    echo "  3. Add your API keys to .mcp.env for full functionality"
    echo "  4. Check logs if something isn't working"
    echo ""
    echo -e "${YELLOW}💡 Pro tips:${NC}"
    echo "  - Edit .mcp.env to add your GitHub/Brave API keys"
    echo "  - Check interceptor logs: docker compose logs mcp-gateway"
    echo "  - Monitor security events in /tmp/sessions/ inside containers"
    echo ""
    echo -e "${GREEN}Ready to push to production? Update the repo and create PRs!${NC}"
    echo ""
}

# Main execution
main() {
    print_banner
    
    log "Starting MobyAgent local setup..."
    
    # Collect user preferences
    echo -e "${BLUE}This script will create a complete MobyAgent setup for local testing.${NC}"
    echo ""
    read -p "Continue with setup? (Y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo "Setup cancelled."
        exit 0
    fi
    
    # Run setup steps
    check_prerequisites
    setup_project_structure
    create_compose_file
    create_mcp_env
    create_interceptors
    create_agent
    create_ui
    create_configs
    create_test_script
    setup_docker_model_runner
    deploy_stack
    run_tests
    show_next_steps
    
    log "🎉 MobyAgent setup complete!"
}

# Run main function
main "$@"
EOF
chmod +x setup_mobyagent.sh
