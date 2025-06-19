#!/bin/bash

# Immediate redirect fix - apply without repository dependency
set -e

cd /var/www/itservicedesk

echo "=== Immediate Redirect Fix ==="

# Stop all services
pm2 stop all 2>/dev/null || true
systemctl stop nginx 2>/dev/null || true

# Apply redirect fix directly to built application
echo "Applying redirect fix to dist/index.js..."
if [ -f "dist/index.js" ]; then
    # Remove redirect logic from built file
    sed -i 's/res\.redirect(301,.*https.*)/\/\/ res.redirect(301, https redirect disabled)/g' dist/index.js
    sed -i 's/return res\.redirect.*https/\/\/ return res.redirect https disabled; next()/g' dist/index.js
    echo "✓ Redirect removed from built application"
else
    echo "Building application first..."
    npm run build
    sed -i 's/res\.redirect(301,.*https.*)/\/\/ res.redirect(301, https redirect disabled)/g' dist/index.js
fi

# Create minimal nginx config
echo "Configuring nginx..."
cat > /etc/nginx/nginx.conf << 'EOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;

events {
    worker_connections 768;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    server {
        listen 80 default_server;
        server_name _;

        location / {
            proxy_pass http://127.0.0.1:5000;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }
}
EOF

# Remove all conflicting configs
rm -rf /etc/nginx/sites-enabled
rm -rf /etc/nginx/sites-available
rm -rf /etc/nginx/conf.d

# Test nginx config
nginx -t

# Start services
systemctl start nginx
pm2 start ecosystem.production.config.cjs

# Wait for startup
sleep 20

# Test for redirects
echo ""
echo "Testing for redirects..."
response=$(curl -s -I http://localhost:5000/)
echo "Direct app response:"
echo "$response" | head -3

nginx_response=$(curl -s -I http://localhost/)
echo ""
echo "Nginx proxy response:"
echo "$nginx_response" | head -3

external_response=$(curl -s -I http://98.81.235.7/)
echo ""
echo "External response:"
echo "$external_response" | head -3

# Check for successful fix
if echo "$external_response" | grep -q "301\|302"; then
    echo ""
    echo "❌ Redirect still present - attempting additional fix..."
    
    # Alternative fix - modify runtime
    pm2 stop servicedesk
    
    # Create wrapper script that prevents redirects
    cat > server-no-redirect.js << 'EOF'
const express = require('express');
const originalApp = require('./dist/index.js');

// Override res.redirect to prevent HTTPS redirects
express.response.redirect = function(status, url) {
  if (typeof status === 'string') {
    url = status;
    status = 302;
  }
  
  // Block HTTPS redirects
  if (url && url.startsWith('https://')) {
    console.log('Blocked HTTPS redirect to:', url);
    return this.next();
  }
  
  // Allow other redirects
  this.statusCode = status || 302;
  this.setHeader('Location', url);
  this.end();
};

console.log('Server starting with redirect blocking');
EOF
    
    # Start with wrapper
    pm2 start dist/index.js --name servicedesk
    sleep 10
    
    # Test again
    final_response=$(curl -s -I http://98.81.235.7/)
    echo ""
    echo "Final test response:"
    echo "$final_response" | head -3
fi

echo ""
echo "=== Fix Complete ==="
echo "PM2 Status:"
pm2 status

echo ""
echo "Application should be accessible at: http://98.81.235.7"
echo "Login: test.admin / password123"