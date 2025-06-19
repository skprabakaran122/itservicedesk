#!/bin/bash

# Fix HTTP access - remove HTTPS redirects
set -e

cd /var/www/itservicedesk

echo "=== Configuring HTTP Access ==="

# Configure nginx for HTTP only (no HTTPS redirects)
cat > /etc/nginx/sites-available/servicedesk << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    
    # Serve the application directly via HTTP
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
    
    # Disable any SSL redirects
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
}
EOF

# Remove any HTTPS configurations
rm -f /etc/nginx/sites-enabled/*ssl*
rm -f /etc/nginx/sites-enabled/default*

# Enable HTTP configuration
ln -sf /etc/nginx/sites-available/servicedesk /etc/nginx/sites-enabled/

# Test and restart nginx
nginx -t
systemctl restart nginx

# Verify services are running
echo "Service status:"
systemctl status nginx --no-pager -l | head -5
pm2 status

# Test HTTP access
echo "Testing HTTP access:"
curl -s -I http://localhost/ | head -3

echo ""
echo "=== HTTP Access Configured ==="
echo "✓ Nginx serving HTTP on port 80"
echo "✓ No HTTPS redirects or SSL requirements"
echo "✓ Direct HTTP access to your IT Service Desk"
echo ""
echo "Access at: http://98.81.235.7"
echo "Login: test.admin / password123"