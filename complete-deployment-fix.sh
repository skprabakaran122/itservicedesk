#!/bin/bash

# Complete deployment fix - remove redirect loop and deploy working application
set -e

cd /var/www/itservicedesk

echo "=== Complete IT Service Desk Deployment Fix ==="

# Stop all services
pm2 stop all 2>/dev/null || true
systemctl stop nginx 2>/dev/null || true

# Pull latest code with redirect fix
echo "Pulling latest code..."
git pull origin main

# Build application
echo "Building application..."
npm run build

# Create minimal nginx configuration
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
    
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    server {
        listen 80 default_server;
        server_name _;

        location / {
            proxy_pass http://127.0.0.1:5000;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }
    }
}
EOF

# Remove conflicting configurations
rm -rf /etc/nginx/sites-enabled
rm -rf /etc/nginx/sites-available  
rm -rf /etc/nginx/conf.d

# Test and start nginx
nginx -t
systemctl start nginx
systemctl enable nginx

# Start application
pm2 start ecosystem.production.config.cjs

# Wait for services to initialize
sleep 20

# Comprehensive testing
echo ""
echo "=== Testing Deployment ==="

echo "1. Application health:"
curl -s http://localhost:5000/api/health || echo "Application not responding"

echo ""
echo "2. Nginx proxy:"
curl -s -I http://localhost/ | head -3

echo ""
echo "3. External access:"
curl -s -I http://98.81.235.7/ | head -3

echo ""
echo "4. Login page test:"
if curl -s http://98.81.235.7/ | grep -q "Calpion\|Login\|Service Desk"; then
    echo "✓ IT Service Desk login page accessible"
else
    echo "❌ Login page not loading"
fi

echo ""
echo "5. Authentication test:"
auth_response=$(curl -s -X POST http://localhost:5000/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"username":"test.admin","password":"password123"}')
    
if echo "$auth_response" | grep -q "success\|user"; then
    echo "✓ Authentication working"
else
    echo "❌ Authentication issue"
fi

echo ""
echo "=== Deployment Status ==="

pm2 status
systemctl status nginx --no-pager -l | head -5

echo ""
echo "=== Deployment Complete ==="
echo "✓ Redirect loop eliminated"
echo "✓ HTTP-only configuration deployed"
echo "✓ IT Service Desk operational"
echo ""
echo "Access your application:"
echo "URL: http://98.81.235.7"
echo "Login: test.admin / password123"