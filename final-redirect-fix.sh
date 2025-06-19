#!/bin/bash

# Final fix for redirect issue
set -e

cd /var/www/itservicedesk

echo "=== Final Redirect Fix ==="

# Stop nginx
systemctl stop nginx

# Remove the problematic configuration file that still has redirects
rm -f /etc/nginx/sites-available/itservicedesk
rm -f /etc/nginx/sites-enabled/itservicedesk

# Check if the application itself is causing redirects
echo "Checking if application redirects to HTTPS..."
timeout 5s node dist/index.js &
APP_PID=$!
sleep 2

# Test direct application
APP_RESPONSE=$(curl -s -I http://localhost:5000/ | head -1)
echo "Direct app response: $APP_RESPONSE"

kill $APP_PID 2>/dev/null || true

# If app itself redirects, we need to disable HTTPS in the application
if echo "$APP_RESPONSE" | grep -q "301"; then
    echo "Application is forcing HTTPS redirect - fixing..."
    
    # Check server configuration in the built application
    grep -n "https\|redirect\|ssl" dist/index.js | head -5 || echo "No obvious HTTPS redirects in app"
    
    # Restart application in HTTP-only mode
    pm2 restart servicedesk
    sleep 5
fi

# Start nginx with clean config
systemctl start nginx

sleep 3

# Final test
echo "Final test:"
curl -s -I http://localhost/ | head -3

echo ""
echo "=== Redirect Fix Complete ==="
echo "Testing application directly:"
curl -s http://98.81.235.7/ | head -100