#!/bin/bash

# Fix nginx redirects completely
set -e

cd /var/www/itservicedesk

echo "=== Fixing Nginx Redirects ==="

# Remove ALL nginx configurations
rm -f /etc/nginx/sites-enabled/*
rm -f /etc/nginx/sites-available/default*

# Create clean HTTP-only configuration
cat > /etc/nginx/sites-available/servicedesk << 'EOF'
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
EOF

# Enable only our configuration
ln -sf /etc/nginx/sites-available/servicedesk /etc/nginx/sites-enabled/servicedesk

# Remove main nginx redirects
cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup
sed -i '/return 301/d' /etc/nginx/nginx.conf
sed -i '/redirect/d' /etc/nginx/nginx.conf

# Test and restart
nginx -t
systemctl restart nginx

sleep 3

# Test HTTP access without redirects
echo "Testing direct HTTP access:"
curl -s -I http://localhost/ | head -3

echo "Testing external access:"
curl -s -I http://98.81.235.7/ | head -3

echo ""
echo "✓ All redirects removed"
echo "✓ Direct HTTP access configured"
echo "✓ IT Service Desk accessible at http://98.81.235.7"