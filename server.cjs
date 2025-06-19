const express = require('express');
const path = require('path');
const { spawn } = require('child_process');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true }));

// Trust proxy for nginx
app.set('trust proxy', true);

// Serve static files from the built frontend
const staticPath = path.join(__dirname, 'dist', 'public');
app.use(express.static(staticPath));

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV || 'development'
  });
});

// Start the actual TypeScript server as a child process
console.log('Starting TypeScript server...');
const serverProcess = spawn('node', ['--loader', 'tsx/esm', 'server/index.ts'], {
  stdio: 'inherit',
  env: { ...process.env, NODE_ENV: 'production', PORT: '3001' }
});

// Proxy API requests to the TypeScript server
app.use('/api', (req, res) => {
  const proxyReq = require('http').request({
    hostname: 'localhost',
    port: 3001,
    path: req.url,
    method: req.method,
    headers: req.headers
  }, (proxyRes) => {
    res.writeHead(proxyRes.statusCode, proxyRes.headers);
    proxyRes.pipe(res);
  });
  
  proxyReq.on('error', (err) => {
    console.error('Proxy error:', err);
    res.status(502).json({ error: 'Backend service unavailable' });
  });
  
  if (req.body) {
    proxyReq.write(JSON.stringify(req.body));
  }
  proxyReq.end();
});

// Serve React app for all other routes
app.get('*', (req, res) => {
  res.sendFile(path.join(staticPath, 'index.html'));
});

// Error handling
app.use((err, req, res, next) => {
  console.error('Server error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('Received SIGTERM, shutting down gracefully');
  serverProcess.kill();
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('Received SIGINT, shutting down gracefully');
  serverProcess.kill();
  process.exit(0);
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Production proxy server running on port ${PORT}`);
  console.log(`Serving static files from: ${staticPath}`);
  console.log(`Proxying API requests to TypeScript server on port 5001`);
  console.log(`Application ready at http://localhost:${PORT}`);
});