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
