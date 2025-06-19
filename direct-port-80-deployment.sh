#!/bin/bash

# Deploy application directly on port 80 without nginx
set -e

cd /var/www/itservicedesk

echo "=== Direct Port 80 Deployment ==="

# Stop all web services
systemctl stop nginx 2>/dev/null || true
systemctl stop apache2 2>/dev/null || true
pm2 stop servicedesk 2>/dev/null || true

# Kill any processes using port 80
fuser -k 80/tcp 2>/dev/null || true
sleep 3

# Remove nginx completely
apt-get remove --purge nginx nginx-common nginx-core -y 2>/dev/null || true
rm -rf /etc/nginx 2>/dev/null || true

# Update application configuration for port 80
sed -i 's/PORT: 5000/PORT: 80/' ecosystem.production.config.cjs 2>/dev/null || true

# Create new PM2 config for port 80
cat > ecosystem.port80.config.cjs << 'EOF'
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
      PORT: 80,
      HOST: '0.0.0.0'
    },
    error_file: './logs/error.log',
    out_file: './logs/out.log',
    log_file: './logs/app.log',
    time: true
  }]
};
EOF

# Start application on port 80
pm2 start ecosystem.port80.config.cjs

sleep 15

# Verify application is running
pm2 status

# Test port 80 access
echo "Testing port 80 access:"
curl -s -I http://localhost/ | head -3

# Test application functionality
echo "Testing application endpoints:"
curl -s http://localhost/api/health || echo "Health check pending..."

# Test external access
echo "Testing external access:"
curl -s -I http://98.81.235.7/ | head -3

echo ""
echo "=== Direct Port 80 Deployment Complete ==="
echo "✓ Application running directly on port 80"
echo "✓ No nginx proxy layer"
echo "✓ Direct HTTP access without redirects"
echo ""
echo "Access your IT Service Desk at: http://98.81.235.7"
echo "Monitor: pm2 logs servicedesk"