const express = require('express');
const cors = require('cors');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());
app.use(express.static('public'));

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

// API health check endpoint
app.get('/api/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

// Root endpoint
app.get('/', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html>
    <head>
        <title>🐳 AgentMoby UI</title>
        <style>
            body { font-family: Arial, sans-serif; padding: 2rem; }
            .status { background: #f0f8ff; padding: 1rem; border-radius: 5px; margin: 1rem 0; }
            a { color: #007acc; text-decoration: none; }
            a:hover { text-decoration: underline; }
        </style>
    </head>
    <body>
        <h1>🐳 AgentMoby UI</h1>
        <p>Welcome to the AgentMoby Agent Interface</p>
        
        <div class="status">
            <h2>Service Status</h2>
            <p>UI Service: ✅ Running</p>
            <p>API Base URL: ${process.env.API_BASE_URL || 'http://localhost:8000'}</p>
        </div>

        <h2>Quick Links</h2>
        <ul>
            <li><a href="http://localhost:9090">Frontend (Port 9090)</a></li>
            <li><a href="http://localhost:8000">ADK API (Port 8000)</a></li>
            <li><a href="http://localhost:8811">MCP Gateway (Port 8811)</a></li>
            <li><a href="http://localhost:8081">Catalogue (Port 8081)</a></li>
        </ul>

        <script>
            // Check API connectivity
            fetch('${process.env.API_BASE_URL || 'http://localhost:8000'}/health')
                .then(res => res.json())
                .then(data => {
                    document.querySelector('.status').innerHTML += 
                        '<p>ADK API: ✅ Connected (' + data.status + ')</p>';
                })
                .catch(() => {
                    document.querySelector('.status').innerHTML += 
                        '<p>ADK API: ❌ Not connected</p>';
                });
        </script>
    </body>
    </html>
  `);
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`UI Service running on port ${PORT}`);
});
