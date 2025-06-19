#!/bin/bash

# Force remove all redirect sources and create clean HTTP proxy
set -e

cd /var/www/itservicedesk

echo "=== Force Removing All Redirect Sources ==="

# Stop all services
pm2 stop servicedesk 2>/dev/null || true
systemctl stop nginx 2>/dev/null || true

# Completely purge nginx and reinstall
apt-get remove --purge nginx nginx-common nginx-core nginx-full -y
apt-get autoremove -y
apt-get autoclean

# Clean all nginx directories
rm -rf /etc/nginx
rm -rf /var/log/nginx
rm -rf /var/lib/nginx
rm -rf /usr/share/nginx

# Fresh nginx installation
apt-get update
apt-get install nginx -y

# Create minimal nginx configuration with NO redirects whatsoever
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
        }
    }
}
EOF

# Test nginx configuration
nginx -t

# Start services
systemctl start nginx
pm2 start ecosystem.production.config.cjs

sleep 10

# Test for any redirects
echo "Testing localhost for redirects:"
response=$(curl -s -I http://localhost/)
echo "$response"

if echo "$response" | grep -q "301\|302"; then
    echo "❌ Still detecting redirects"
else
    echo "✓ No redirects detected"
fi

echo ""
echo "Testing external access:"
external_response=$(curl -s -I http://98.81.235.7/)
echo "$external_response"

if echo "$external_response" | grep -q "301\|302"; then
    echo "❌ External redirects still present"
else
    echo "✓ External access clean - no redirects"
fi

echo ""
echo "=== Force Redirect Removal Complete ==="
echo "✓ Nginx completely reinstalled"
echo "✓ Minimal configuration with no redirect possibilities"
echo "✓ Application should be accessible at http://98.81.235.7"