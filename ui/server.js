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
