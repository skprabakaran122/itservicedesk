#!/bin/bash

# Fix nginx configuration to use correct server IP
set -e

echo "=== Fixing nginx configuration for server IP 98.81.235.7 ==="

# Update nginx configuration with correct server IP
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

# Test nginx configuration
nginx -t

# Reload nginx to apply changes
systemctl reload nginx

echo "✓ Nginx configuration updated for server IP 98.81.235.7"
echo "✓ Configuration tested and reloaded"
echo ""
echo "Your IT Service Desk is now properly configured at: http://98.81.235.7"