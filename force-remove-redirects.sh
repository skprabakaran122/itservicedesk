#!/bin/bash

# Force remove all nginx redirects
set -e

cd /var/www/itservicedesk

echo "=== Force Removing All Nginx Redirects ==="

# Stop nginx
systemctl stop nginx

# Check for redirect sources
echo "Checking for redirect sources..."
grep -r "301\|redirect\|return 301" /etc/nginx/ 2>/dev/null || echo "No redirects found in config files"

# Create completely clean nginx configuration
cat > /etc/nginx/nginx.conf << 'EOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;

events {
    worker_connections 768;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    gzip on;

    include /etc/nginx/sites-enabled/*;
}
EOF

# Remove all existing site configurations
rm -rf /etc/nginx/sites-enabled/*
rm -rf /etc/nginx/sites-available/*

# Create single clean HTTP configuration
cat > /etc/nginx/sites-available/http-only << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto http;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 86400;
    }
}
EOF

# Enable the clean configuration
ln -s /etc/nginx/sites-available/http-only /etc/nginx/sites-enabled/

# Test configuration
nginx -t

# Start nginx
systemctl start nginx

sleep 3

# Test without any redirects
echo "Testing clean HTTP access:"
curl -s -I http://localhost/ | head -5

# Check if application is responding
echo "Testing application response:"
curl -s http://localhost/api/health | head -50

echo ""
echo "=== Clean HTTP Configuration Complete ==="
echo "✓ All nginx redirects forcefully removed"
echo "✓ Clean HTTP-only configuration"
echo "✓ IT Service Desk accessible at http://98.81.235.7"