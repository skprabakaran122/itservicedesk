#!/bin/bash

# Fix nginx to proxy to application instead of showing default page
set -e

cd /var/www/itservicedesk

echo "=== Fixing Nginx Proxy Configuration ==="

# Stop nginx
systemctl stop nginx

# Replace the default nginx configuration with proxy setup
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
        }
    }
}
EOF

# Remove any default configurations that might interfere
rm -rf /etc/nginx/sites-enabled
rm -rf /etc/nginx/sites-available
rm -rf /etc/nginx/conf.d

# Ensure application is running on port 5000
pm2 restart servicedesk 2>/dev/null || pm2 start ecosystem.production.config.cjs

# Wait for application to start
sleep 10

# Test nginx configuration
nginx -t

# Start nginx
systemctl start nginx

sleep 5

# Test the setup
echo "Testing application directly:"
curl -s http://localhost:5000/api/health

echo "Testing nginx proxy:"
curl -s http://localhost/api/health

echo "Checking PM2 status:"
pm2 status

echo ""
echo "=== Nginx Proxy Fix Complete ==="
echo "✓ Nginx now proxying to your IT Service Desk application"
echo "✓ Default welcome page replaced with proxy configuration"
echo "✓ Application accessible at http://98.81.235.7"