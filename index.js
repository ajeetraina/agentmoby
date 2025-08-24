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
