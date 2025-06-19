#!/bin/bash

# Fix all port inconsistencies - standardize on port 3000
set -e

echo "=== Fixing Port Inconsistencies ==="
echo "Standardizing all configurations to use port 3000"

# 1. Create consistent production server
echo "1. Creating production server with port 3000..."
cat > server-production.cjs << 'EOF'
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
EOF

# 2. Update ecosystem production config
echo "2. Updating PM2 production configuration..."
cat > ecosystem.production.config.cjs << 'EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'server-production.cjs',
    cwd: '/var/www/itservicedesk',
    instances: 1,
    exec_mode: 'fork',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    error_file: './logs/error.log',
    out_file: './logs/out.log',
    log_file: './logs/app.log',
    time: true,
    max_memory_restart: '1G',
    restart_delay: 4000,
    watch: false,
    kill_timeout: 5000
  }]
};
EOF

# 3. Create systemd service for port 3000
echo "3. Creating systemd service configuration..."
cat > itservicedesk.service << 'EOF'
[Unit]
Description=Calpion IT Service Desk
After=network.target postgresql.service

[Service]
Type=simple
User=www-data
WorkingDirectory=/var/www/itservicedesk
ExecStart=/usr/bin/node server-production.cjs
Environment=NODE_ENV=production
Environment=PORT=3000
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=itservicedesk

[Install]
WantedBy=multi-user.target
EOF

# 4. Create nginx configuration for port 3000
echo "4. Creating nginx configuration..."
cat > nginx-itservicedesk.conf << 'EOF'
server {
    listen 80 default_server;
    server_name 98.81.235.7 _;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # Main application proxy to port 3000
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        
        # Timeouts
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
        
        # Buffer settings
        proxy_buffering on;
        proxy_buffer_size 128k;
        proxy_buffers 4 256k;
        proxy_busy_buffers_size 256k;
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        proxy_pass http://127.0.0.1:3000/health;
    }
}
EOF

# 5. Fix deployment scripts with correct ports
echo "5. Updating key deployment scripts..."

# Update complete-production-deployment.sh
sed -i 's/proxy_pass http:\/\/127\.0\.0\.1:5000/proxy_pass http:\/\/127.0.0.1:3000/g' complete-production-deployment.sh 2>/dev/null || true

# Update deploy-to-ubuntu.sh  
sed -i 's/PORT: 5000/PORT: 3000/g' deploy-to-ubuntu.sh 2>/dev/null || true
sed -i 's/port 5000/port 3000/g' deploy-to-ubuntu.sh 2>/dev/null || true

# Update fix-connection-reset.sh
sed -i 's/proxy_pass http:\/\/127\.0\.0\.1:5000/proxy_pass http:\/\/127.0.0.1:3000/g' fix-connection-reset.sh 2>/dev/null || true

echo ""
echo "=== Port Standardization Complete ==="
echo "✓ All configurations now use port 3000"
echo "✓ Production server: server-production.cjs (port 3000)"
echo "✓ SystemD service: itservicedesk.service (port 3000)"  
echo "✓ Nginx proxy: nginx-itservicedesk.conf (port 3000)"
echo "✓ PM2 config: ecosystem.production.config.cjs (port 3000)"
echo ""
echo "Files created for Ubuntu deployment:"
echo "- server-production.cjs (production server)"
echo "- itservicedesk.service (systemd service)"
echo "- nginx-itservicedesk.conf (nginx config)"
echo "- ecosystem.production.config.cjs (PM2 config)"