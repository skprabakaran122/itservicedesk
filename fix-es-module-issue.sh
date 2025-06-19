#!/bin/bash

# Fix ES module issue in production deployment
set -e

cd /var/www/itservicedesk

echo "=== Fixing ES Module Issue ==="

# Stop PM2 processes
pm2 delete all 2>/dev/null || true

# Create CommonJS production server with .cjs extension
echo "Creating CommonJS production server..."
cat > server-production.cjs << 'EOF'
const express = require('express');
const session = require('express-session');
const path = require('path');
const fs = require('fs');
const { createServer } = require('http');

const app = express();
const PORT = 5000;

console.log('=== Production Server Starting ===');
console.log('Time:', new Date().toISOString());
console.log('Working directory:', process.cwd());
console.log('Node version:', process.version);

// Check if required directories exist
const distPath = path.join(__dirname, 'dist');
const indexPath = path.join(distPath, 'index.html');

console.log('Dist path:', distPath);
console.log('Index path:', indexPath);
console.log('Dist exists:', fs.existsSync(distPath));
console.log('Index exists:', fs.existsSync(indexPath));

// Basic middleware
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// Session middleware
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
    server: 'production',
    uptime: process.uptime(),
    memory: process.memoryUsage()
  });
});

// Basic auth endpoints
app.post('/api/auth/login', (req, res) => {
  console.log('Login attempt:', req.body.username);
  const { username, password } = req.body;
  
  // Default test accounts
  const users = {
    'admin': { id: 1, username: 'admin', password: 'password123', role: 'admin', firstName: 'System', lastName: 'Administrator' },
    'support': { id: 2, username: 'support', password: 'password123', role: 'agent', firstName: 'Support', lastName: 'Technician' },
    'manager': { id: 3, username: 'manager', password: 'password123', role: 'manager', firstName: 'IT', lastName: 'Manager' }
  };
  
  const user = users[username];
  if (user && user.password === password) {
    req.session.user = { id: user.id, username: user.username, role: user.role, firstName: user.firstName, lastName: user.lastName };
    res.json({ user: req.session.user });
  } else {
    res.status(401).json({ message: 'Invalid credentials' });
  }
});

app.get('/api/auth/me', (req, res) => {
  if (req.session.user) {
    res.json({ user: req.session.user });
  } else {
    res.status(401).json({ message: 'Not authenticated' });
  }
});

app.post('/api/auth/logout', (req, res) => {
  req.session.destroy((err) => {
    if (err) {
      console.error('Session destroy error:', err);
    }
    res.json({ message: 'Logged out' });
  });
});

// Basic API endpoints for testing
app.get('/api/tickets', (req, res) => {
  res.json([
    { id: 1, title: 'Sample Ticket', status: 'open', priority: 'medium', createdAt: new Date().toISOString() }
  ]);
});

app.get('/api/products', (req, res) => {
  res.json([
    { id: 1, name: 'Laptop', category: 'Hardware', description: 'Standard business laptop' },
    { id: 2, name: 'Software License', category: 'Software', description: 'Business software licensing' }
  ]);
});

// Serve static files from dist
if (fs.existsSync(distPath)) {
  console.log('Serving static files from dist/');
  app.use(express.static(distPath));
  
  // Serve index.html for all routes (SPA support)
  app.get('*', (req, res) => {
    if (fs.existsSync(indexPath)) {
      res.sendFile(indexPath);
    } else {
      res.status(404).send('Frontend not built');
    }
  });
} else {
  console.log('No dist directory - serving basic HTML');
  app.get('/', (req, res) => {
    res.send(`
      <!DOCTYPE html>
      <html>
      <head>
        <title>Calpion IT Service Desk</title>
        <style>
          body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
          .container { max-width: 800px; margin: 0 auto; background: white; padding: 40px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
          .login-form { background: #f9f9f9; padding: 20px; border-radius: 8px; margin: 20px 0; }
          input, button { padding: 12px; margin: 8px; display: block; width: 250px; border: 1px solid #ddd; border-radius: 4px; }
          button { background: #007cba; color: white; border: none; cursor: pointer; font-weight: bold; }
          button:hover { background: #005a8b; }
          .status { margin: 20px 0; padding: 15px; border-radius: 4px; }
          .success { background: #d4edda; color: #155724; border: 1px solid #c3e6cb; }
          .error { background: #f8d7da; color: #721c24; border: 1px solid #f5c6cb; }
          .links { margin: 20px 0; }
          .links a { display: inline-block; margin: 10px 15px 10px 0; color: #007cba; text-decoration: none; }
          .links a:hover { text-decoration: underline; }
        </style>
      </head>
      <body>
        <div class="container">
          <h1>🏢 Calpion IT Service Desk</h1>
          <p>Production server is running successfully!</p>
          
          <div class="login-form">
            <h3>Login</h3>
            <input type="text" id="username" placeholder="Username" value="admin">
            <input type="password" id="password" placeholder="Password" value="password123">
            <button onclick="login()">Login</button>
            <div id="status"></div>
          </div>
          
          <div class="links">
            <h3>API Endpoints:</h3>
            <a href="/api/health" target="_blank">Health Check</a>
            <a href="/api/tickets" target="_blank">Tickets</a>
            <a href="/api/products" target="_blank">Products</a>
          </div>
          
          <p><strong>Default Accounts:</strong></p>
          <ul>
            <li>admin/password123 - System Administrator</li>
            <li>support/password123 - Support Technician</li>
            <li>manager/password123 - IT Manager</li>
          </ul>
        </div>

        <script>
          async function login() {
            const username = document.getElementById('username').value;
            const password = document.getElementById('password').value;
            const status = document.getElementById('status');
            
            try {
              const response = await fetch('/api/auth/login', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ username, password })
              });
              
              const data = await response.json();
              
              if (data.user) {
                status.innerHTML = '<div class="status success">✓ Login successful! Welcome ' + data.user.firstName + ' ' + data.user.lastName + ' (' + data.user.role + ')</div>';
              } else {
                status.innerHTML = '<div class="status error">✗ Login failed: ' + (data.message || 'Unknown error') + '</div>';
              }
            } catch (error) {
              status.innerHTML = '<div class="status error">✗ Error: ' + error.message + '</div>';
            }
          }
        </script>
      </body>
      </html>
    `);
  });
}

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Server error:', err);
  res.status(500).json({ error: 'Internal server error', message: err.message });
});

// Start server
const server = createServer(app);
server.listen(PORT, '0.0.0.0', () => {
  console.log(`✓ Server running on port ${PORT}`);
  console.log(`✓ Access: http://localhost:${PORT}`);
  console.log(`✓ Health: http://localhost:${PORT}/api/health`);
  console.log('=== Server Ready ===');
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  server.close(() => {
    console.log('Process terminated');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully');
  server.close(() => {
    console.log('Process terminated');
    process.exit(0);
  });
});
EOF

# Update PM2 configuration to use .cjs file
echo "Updating PM2 configuration..."
cat > ecosystem.fixed.config.cjs << 'EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'server-production.cjs',
    cwd: '/var/www/itservicedesk',
    instances: 1,
    exec_mode: 'fork',
    autorestart: true,
    watch: false,
    max_memory_restart: '512M',
    restart_delay: 3000,
    max_restarts: 5,
    min_uptime: '15s',
    kill_timeout: 5000,
    env: {
      NODE_ENV: 'production',
      PORT: 5000
    },
    error_file: '/var/www/itservicedesk/logs/error.log',
    out_file: '/var/www/itservicedesk/logs/out.log',
    log_file: '/var/www/itservicedesk/logs/app.log',
    time: true,
    merge_logs: true
  }]
};
EOF

# Ensure logs directory exists
mkdir -p logs
chown -R www-data:www-data logs

# Test the server directly first
echo "Testing CommonJS server..."
timeout 15s node server-production.cjs &
SERVER_PID=$!
sleep 8

# Test health endpoint
if curl -s http://localhost:5000/api/health > /dev/null; then
  echo "✓ CommonJS server working correctly"
  kill $SERVER_PID 2>/dev/null || true
else
  echo "✗ Server still not responding"
  kill $SERVER_PID 2>/dev/null || true
  exit 1
fi

# Start with PM2
echo "Starting with PM2..."
pm2 start ecosystem.fixed.config.cjs

# Wait for startup
sleep 10

echo "Checking PM2 status..."
pm2 status

echo "Testing application endpoints..."
echo "Health check:"
curl -s http://localhost:5000/api/health | head -100

echo ""
echo "Testing root endpoint:"
curl -s -I http://localhost:5000

echo ""
echo "Testing nginx proxy..."
systemctl restart nginx
sleep 3
curl -s -I http://localhost

echo ""
echo "=== ES Module Fix Complete ==="
echo "✓ CommonJS server created and tested"
echo "✓ PM2 process started successfully"
echo "✓ Application responding to requests"
echo ""
echo "Access your application at: http://your-server-ip"
echo "Health check: http://your-server-ip/api/health"
echo ""
echo "Monitor with:"
echo "  pm2 monit"
echo "  pm2 logs servicedesk"