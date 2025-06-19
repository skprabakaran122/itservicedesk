#!/bin/bash

echo "=== Quick Status Check ==="

echo "1. Checking PM2 status..."
pm2 status

echo ""
echo "2. Checking if port 5000 is listening..."
ss -tlnp | grep :5000 || echo "Port 5000 not listening"

echo ""
echo "3. Testing direct application connection..."
curl -v http://localhost:5000/api/health 2>&1 | head -20

echo ""
echo "4. Checking nginx configuration..."
cat /etc/nginx/sites-enabled/servicedesk | head -20

echo ""
echo "5. Testing nginx proxy..."
curl -v http://localhost/ 2>&1 | head -20

echo ""
echo "6. Checking application logs..."
pm2 logs servicedesk --lines 10 --nostream

echo ""
echo "=== Status Check Complete ==="