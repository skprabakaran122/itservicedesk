#!/bin/bash

# Fix nginx port mismatch - app is on port 3000, nginx expects port 5000
set -e

echo "=== Fixing nginx port mismatch ==="

echo "1. Your Node.js app is running on port 3000"
echo "2. But nginx is configured to proxy to port 5000"
echo "3. Updating nginx configuration to use port 3000..."

# Update nginx configuration to proxy to port 3000 instead of 5000
cat > /etc/nginx/sites-available/itservicedesk << 'EOF'
server {
    listen 80;
    server_name 98.81.235.7 _;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
        proxy_read_timeout 300;
    }
}
EOF

echo "4. Testing nginx configuration..."
nginx -t

echo "5. Reloading nginx..."
systemctl reload nginx

echo "6. Installing net-tools for better debugging..."
apt-get update && apt-get install -y net-tools

echo "7. Verifying port 3000 is listening..."
netstat -tlnp | grep :3000

echo "8. Testing local connection to port 3000..."
curl -I http://localhost:3000

echo ""
echo "=== Fix Complete ==="
echo "✓ Nginx now correctly proxies to port 3000"
echo "✓ Your IT Service Desk should now be accessible at http://98.81.235.7"
echo ""
echo "Test it now in your browser: http://98.81.235.7"