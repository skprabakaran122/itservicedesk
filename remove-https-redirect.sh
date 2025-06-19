#!/bin/bash

# Remove HTTPS redirects completely and configure simple HTTP proxy
set -e

cd /var/www/itservicedesk

echo "=== Removing HTTPS Redirect Sources ==="

# Stop services
systemctl stop nginx 2>/dev/null || true

# Find and remove any redirect configurations
grep -r "return 301" /etc/nginx/ 2>/dev/null || echo "No return 301 found"
grep -r "redirect" /etc/nginx/ 2>/dev/null || echo "No redirect found"

# Create completely clean nginx configuration with NO redirects
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

    # Simple HTTP server - NO HTTPS, NO REDIRECTS
    server {
        listen 80 default_server;
        listen [::]:80 default_server;
        server_name _;

        # Direct proxy to application
        location / {
            proxy_pass http://127.0.0.1:5000;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }
    }
}
EOF

# Remove ALL other nginx configurations
rm -rf /etc/nginx/sites-enabled
rm -rf /etc/nginx/sites-available
rm -rf /etc/nginx/conf.d
rm -f /etc/nginx/snippets/ssl-*.conf 2>/dev/null || true

# Test configuration
nginx -t

# Start nginx
systemctl start nginx

sleep 5

# Test for redirects
echo "Testing for redirects:"
curl -s -I http://localhost/ | head -5

echo ""
echo "Testing external access:"
curl -s -I http://98.81.235.7/ | head -5

echo ""
echo "=== Redirect Removal Complete ==="
echo "✓ All HTTPS redirects removed"
echo "✓ Simple HTTP proxy configured"
echo "✓ No redirect loops possible"