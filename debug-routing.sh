#!/bin/bash

# Debug routing issues on Ubuntu server
cd /var/www/itservicedesk

echo "=== Ubuntu Server Routing Debug ==="
echo "Current directory: $(pwd)"
echo "Date: $(date)"
echo ""

echo "1. Checking PM2 process status..."
pm2 list
echo ""

echo "2. Checking recent PM2 logs..."
pm2 logs itservicedesk --lines 10
echo ""

echo "3. Checking file structure..."
echo "dist/ contents:"
ls -la dist/
echo ""
echo "dist/public/ contents:"
ls -la dist/public/ 2>/dev/null || echo "dist/public/ does not exist"
echo ""

echo "4. Testing server responses..."
echo "Health check:"
curl -s http://localhost:5000/health | jq . 2>/dev/null || curl -s http://localhost:5000/health
echo ""

echo "Root path test:"
curl -s -I http://localhost:5000/ | head -5
echo ""

echo "5. Testing authentication flow..."
echo "Login test:"
LOGIN_RESPONSE=$(curl -s -c /tmp/cookies.txt -X POST http://localhost:5000/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"username":"admin","password":"password123"}')
echo "$LOGIN_RESPONSE"
echo ""

echo "Session test:"
curl -s -b /tmp/cookies.txt http://localhost:5000/api/auth/me
echo ""

echo "6. Testing static file serving..."
echo "Checking for index.html:"
curl -s -I http://localhost:5000/index.html | head -3
echo ""

echo "7. Checking nginx status and config..."
sudo systemctl status nginx --no-pager -l
echo ""

echo "Nginx config for IT Service Desk:"
sudo cat /etc/nginx/sites-available/itservicedesk 2>/dev/null || echo "No nginx config found"
echo ""

echo "8. Checking port 5000 connectivity..."
netstat -tlnp | grep :5000
echo ""

echo "9. Testing direct HTTPS access..."
curl -s -k -I https://localhost/ | head -3
echo ""

echo "=== Debug Complete ==="