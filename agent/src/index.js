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
