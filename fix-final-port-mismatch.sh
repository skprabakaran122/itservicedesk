#!/bin/bash

# Fix final port mismatch - update nginx to use port 5000
set -e

echo "=== Fixing Final Port Mismatch ==="

echo "1. Your application is running on port 5000"
echo "2. Updating nginx to proxy to port 5000..."

cat > /etc/nginx/sites-available/itservicedesk << 'EOF'
server {
    listen 80 default_server;
    server_name 98.81.235.7 _;
    
    location /health {
        proxy_pass http://127.0.0.1:5000/health;
        proxy_set_header Host $host;
    }
    
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_connect_timeout 30;
        proxy_send_timeout 30;
        proxy_read_timeout 30;
    }
}
EOF

echo "3. Testing nginx configuration..."
nginx -t

echo "4. Reloading nginx..."
systemctl reload nginx

echo "5. Testing final connection..."
curl -f http://localhost:80/health && echo "✓ Everything working correctly"

echo ""
echo "=== Fix Complete ==="
echo "✓ Nginx now correctly proxies to port 5000"
echo "✓ Your IT Service Desk is accessible at http://98.81.235.7"