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
