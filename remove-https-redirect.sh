#!/bin/bash

# Remove HTTPS redirect from application
set -e

cd /var/www/itservicedesk

echo "=== Removing HTTPS Redirect Sources ==="

# Stop services
systemctl stop nginx
pm2 stop servicedesk

# Remove problematic nginx config that has redirect
rm -f /etc/nginx/sites-available/itservicedesk
rm -f /etc/nginx/sites-enabled/itservicedesk

# Check if the application has HTTPS redirect configured
echo "Checking application for HTTPS redirects..."

# Look for HTTPS redirect in the application code
if grep -q "https\|SSL\|redirect.*443" dist/index.js; then
    echo "Found HTTPS references in application"
    
    # Replace any HTTPS redirects with HTTP
    sed -i 's/https:/http:/g' dist/index.js
    sed -i 's/443/80/g' dist/index.js
    sed -i '/redirect.*https/d' dist/index.js
    
    echo "✓ Removed HTTPS references from application"
fi

# Update environment to force HTTP
export NODE_ENV=production
export HTTPS=false
export SSL=false

# Start nginx with clean config (should only have our http-only config)
systemctl start nginx

# Start application without SSL
pm2 start servicedesk

sleep 8

# Test direct application
echo "Testing application directly:"
curl -s -I http://127.0.0.1:5000/ | head -3

# Test through nginx
echo "Testing through nginx:"
curl -s -I http://127.0.0.1/ | head -3

# Test actual response content
echo "Testing actual content:"
curl -s http://127.0.0.1/ | head -50

echo ""
echo "=== HTTPS Redirect Removal Complete ==="
echo "Application should now be accessible via HTTP at 98.81.235.7"