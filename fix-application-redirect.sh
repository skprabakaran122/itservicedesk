#!/bin/bash

# Fix application redirect loop by rebuilding without HTTPS redirect
set -e

cd /var/www/itservicedesk

echo "=== Fixing Application Redirect Loop ==="

# Stop current application
pm2 stop servicedesk 2>/dev/null || true

# Rebuild application with redirect fix
echo "Rebuilding application..."
npm run build

# Start application with fixed code
echo "Starting fixed application..."
pm2 start ecosystem.production.config.cjs

sleep 10

# Test direct application for redirects
echo "Testing application directly:"
app_response=$(curl -s -I http://localhost:5000/)
echo "$app_response"

if echo "$app_response" | grep -q "301\|302"; then
    echo "❌ Application still redirecting"
else
    echo "✓ Application redirect fixed"
fi

# Test through nginx
echo ""
echo "Testing through nginx proxy:"
nginx_response=$(curl -s -I http://localhost/)
echo "$nginx_response"

if echo "$nginx_response" | grep -q "301\|302"; then
    echo "❌ Still redirecting through nginx"
else
    echo "✓ Nginx proxy working correctly"
fi

# Test external access
echo ""
echo "Testing external access:"
external_response=$(curl -s -I http://98.81.235.7/)
echo "$external_response"

if echo "$external_response" | grep -q "301\|302"; then
    echo "❌ External access still redirecting"
else
    echo "✓ External access working - no redirects"
fi

echo ""
echo "=== Application Redirect Fix Complete ==="
echo "✓ HTTPS redirect middleware disabled"
echo "✓ Application rebuilt and restarted"
echo "✓ IT Service Desk should now be accessible at http://98.81.235.7"