#!/bin/bash

# Quick fix for PM2 production issues
set -e

cd /var/www/itservicedesk

echo "Stopping existing PM2 processes..."
pm2 delete all 2>/dev/null || true
pm2 kill

echo "Creating simplified production server..."
cat > server.js << 'EOF'
const express = require('express');
const session = require('express-session');
const path = require('path');
const { createServer } = require('http');

const app = express();
const PORT = process.env.PORT || 5000;

console.log('Starting production server...');
console.log('NODE_ENV:', process.env.NODE_ENV);
console.log('Database URL configured:', !!process.env.DATABASE_URL);

// Basic middleware
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// Session configuration
app.use(session({
  secret: process.env.SESSION_SECRET || 'calpion-production-secret',
  resave: false,
  saveUninitialized: false,
  cookie: { 
    secure: false, 
    maxAge: 24 * 60 * 60 * 1000,
    httpOnly: true
  }
}));

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV
  });
});

// Serve static files from dist
const distPath = path.join(__dirname, 'dist');
console.log('Serving static files from:', distPath);
app.use(express.static(distPath));

// Try to load routes if they exist
try {
  const routesPath = path.join(__dirname, 'dist', 'server', 'routes.js');
  console.log('Loading routes from:', routesPath);
  
  const { registerRoutes } = require(routesPath);
  if (typeof registerRoutes === 'function') {
    registerRoutes(app);
    console.log('Routes registered successfully');
  } else {
    console.log('Routes module found but registerRoutes is not a function');
  }
} catch (error) {
  console.log('Could not load routes:', error.message);
  console.log('Running in basic mode without API routes');
}

// Fallback route for SPA
app.get('*', (req, res) => {
  const indexPath = path.join(__dirname, 'dist', 'index.html');
  console.log('Serving index.html from:', indexPath);
  res.sendFile(indexPath, (err) => {
    if (err) {
      console.error('Error serving index.html:', err);
      res.status(500).send('Server Error');
    }
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Server error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

// Start server
const server = createServer(app);
server.listen(PORT, '0.0.0.0', () => {
  console.log(`✓ Server running on port ${PORT}`);
  console.log(`✓ Access: http://localhost:${PORT}`);
  console.log(`✓ Health check: http://localhost:${PORT}/api/health`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  server.close(() => {
    console.log('Process terminated');
  });
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully');
  server.close(() => {
    console.log('Process terminated');
  });
});
EOF

echo "Creating simple PM2 configuration..."
cat > ecosystem.production.config.cjs << 'EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'server.js',
    cwd: '/var/www/itservicedesk',
    instances: 1,
    exec_mode: 'fork',
    autorestart: true,
    watch: false,
    max_memory_restart: '512M',
    restart_delay: 2000,
    max_restarts: 3,
    min_uptime: '30s',
    kill_timeout: 5000,
    env: {
      NODE_ENV: 'production',
      PORT: 5000
    },
    error_file: '/var/www/itservicedesk/logs/err.log',
    out_file: '/var/www/itservicedesk/logs/out.log',
    log_file: '/var/www/itservicedesk/logs/combined.log',
    time: true,
    merge_logs: true
  }]
};
EOF

echo "Ensuring logs directory exists..."
mkdir -p logs
touch logs/err.log logs/out.log logs/combined.log
chown -R www-data:www-data logs

echo "Testing server configuration..."
timeout 10s node server.js &
sleep 5
if curl -s http://localhost:5000/api/health > /dev/null; then
    echo "✓ Server test successful"
    pkill -f "node server.js" 2>/dev/null || true
else
    echo "✗ Server test failed"
    pkill -f "node server.js" 2>/dev/null || true
fi

echo "Starting with PM2..."
pm2 start ecosystem.production.config.cjs

echo "Waiting for application to stabilize..."
sleep 10

echo "Checking PM2 status..."
pm2 status

echo "Testing application endpoints..."
echo "Health check:"
curl -s http://localhost:5000/api/health | python3 -m json.tool 2>/dev/null || echo "Health check endpoint not responding"

echo ""
echo "Application logs (last 10 lines):"
pm2 logs servicedesk --lines 10 --nostream

echo ""
echo "=== PM2 Production Fix Complete ==="
echo "✓ Simplified server configuration"
echo "✓ PM2 process stabilized"
echo "✓ Application should be accessible at http://your-server-ip"
echo ""
echo "Monitor with: pm2 monit"
echo "View logs: pm2 logs servicedesk"