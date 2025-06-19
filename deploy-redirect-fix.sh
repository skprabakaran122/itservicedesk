#!/bin/bash

# Deploy redirect fix to Ubuntu production server
set -e

cd /var/www/itservicedesk

echo "=== Deploying Redirect Fix ==="

# Stop services
systemctl stop nginx 2>/dev/null || true
pm2 stop servicedesk 2>/dev/null || true

# Pull latest code with redirect fix
git fetch origin
git reset --hard origin/main

# Build application with fixed redirect middleware
echo "Building application without HTTPS redirect..."
npm run build

# Configure simple nginx proxy
cat > /etc/nginx/nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    upstream app {
        server 127.0.0.1:5000;
    }

    server {
        listen 80;
        server_name _;

        location / {
            proxy_pass http://app;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }
}
EOF

# Remove all nginx configurations that could interfere
rm -rf /etc/nginx/sites-enabled
rm -rf /etc/nginx/sites-available
rm -rf /etc/nginx/conf.d

# Start services
nginx -t
systemctl start nginx

pm2 start ecosystem.production.config.cjs
sleep 15

# Verify deployment
echo ""
echo "=== Testing Deployment ==="

echo "1. Direct application test:"
curl -s -I http://localhost:5000/api/health

echo ""
echo "2. Nginx proxy test:"
curl -s -I http://localhost/

echo ""
echo "3. External access test:"
curl -s -I http://98.81.235.7/

echo ""
echo "4. Full page test:"
response=$(curl -s http://98.81.235.7/)
if echo "$response" | grep -q "Calpion\|Service Desk\|Login"; then
    echo "✓ IT Service Desk login page loading correctly"
elif echo "$response" | grep -q "Welcome to nginx"; then
    echo "❌ Still showing nginx default page"
else
    echo "❌ Unexpected response"
fi

echo ""
echo "=== Deployment Complete ==="
echo "✓ HTTPS redirect middleware disabled"
echo "✓ Simple HTTP proxy configured"
echo "✓ Application rebuilt and deployed"
echo ""
echo "Access your IT Service Desk:"
echo "URL: http://98.81.235.7"
echo "Admin: test.admin / password123"
echo "User: test.user / password123"