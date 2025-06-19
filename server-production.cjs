const express = require('express');
const path = require('path');
const app = express();
const PORT = 3000;

console.log('Starting Calpion IT Service Desk...');

// Middleware
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true }));
app.set('trust proxy', true);

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    timestamp: new Date().toISOString(),
    port: PORT,
    service: 'Calpion IT Service Desk'
  });
});

// Serve static frontend files
const staticPath = path.join(__dirname, 'dist', 'public');
app.use(express.static(staticPath));

// API proxy to TypeScript backend
app.use('/api', require('http-proxy-middleware').createProxyMiddleware({
  target: 'http://localhost:3001',
  changeOrigin: true,
  timeout: 30000,
  onError: (err, req, res) => {
    console.error('API Proxy Error:', err.message);
    res.status(502).json({ error: 'Backend service unavailable' });
  }
}));

// Catch-all route for React SPA
app.get('*', (req, res) => {
  res.sendFile(path.join(staticPath, 'index.html'));
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Calpion IT Service Desk running on port ${PORT}`);
  console.log(`Access: http://localhost:${PORT}`);
});

// Start TypeScript backend as child process
const { spawn } = require('child_process');
const backendProcess = spawn('node', ['--loader', 'tsx/esm', 'server/index.ts'], {
  stdio: 'inherit',
  env: { ...process.env, NODE_ENV: 'production', PORT: '3001' }
});

backendProcess.on('error', (err) => {
  console.error('Backend process error:', err);
});

process.on('SIGTERM', () => {
  backendProcess.kill('SIGTERM');
  process.exit(0);
});
