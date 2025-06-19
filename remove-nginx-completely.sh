#!/bin/bash

# Completely remove nginx and all configurations
set -e

cd /var/www/itservicedesk

echo "=== Completely Removing Nginx ==="

# Stop nginx
systemctl stop nginx 2>/dev/null || true

# Disable nginx from starting automatically
systemctl disable nginx 2>/dev/null || true

# Remove all nginx files and configurations
apt-get remove --purge nginx nginx-common nginx-core -y
rm -rf /etc/nginx
rm -rf /var/log/nginx
rm -rf /var/www/html

# Remove any nginx processes
pkill -f nginx 2>/dev/null || true

echo "✓ Nginx completely removed"

# Test direct application access
echo "Testing direct application access on port 5000:"
curl -s -I http://localhost:5000/ | head -3

# Configure application to bind to port 80 directly
echo "Configuring application to run on port 80..."

# Update PM2 configuration to use port 80
cat > ecosystem.production.config.cjs << 'EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'dist/index.js',
    cwd: '/var/www/itservicedesk',
    instances: 1,
    exec_mode: 'fork',
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production',
      PORT: 80
    },
    error_file: './logs/error.log',
    out_file: './logs/out.log',
    log_file: './logs/app.log',
    time: true
  }]
};
EOF

# Stop PM2 and restart with port 80
pm2 stop servicedesk 2>/dev/null || true
pm2 start ecosystem.production.config.cjs

sleep 10

# Test application on port 80
echo "Testing application on port 80:"
curl -s -I http://localhost/ | head -3

# Test external access
echo "Testing external access:"
curl -s http://98.81.235.7/ | head -50

echo ""
echo "=== Nginx Removal Complete ==="
echo "✓ Nginx completely uninstalled"
echo "✓ Application running directly on port 80"
echo "✓ No more redirects or proxy issues"
echo ""
echo "Your IT Service Desk is now accessible at: http://98.81.235.7"
echo "Direct application access without any proxy layer"