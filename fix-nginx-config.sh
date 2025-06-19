#!/bin/bash

# Fix nginx configuration to connect to the correct service
set -e

echo "=== Fixing Nginx Configuration ==="

echo "1. Your Node.js service is running on port 3000"
echo "2. Updating nginx to proxy to the correct service..."

cat > /etc/nginx/sites-available/default << 'EOF'
server {
    listen 80 default_server;
    server_name 98.81.235.7 _;

    location / {
        proxy_pass http://127.0.0.1:3000;
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

echo "5. Testing connection to your service..."
curl -I http://localhost:3000/

echo "6. Testing through nginx..."
curl -I http://localhost/

echo ""
echo "=== Fix Complete ==="
echo "Your IT Service Desk should now be accessible at http://98.81.235.7"