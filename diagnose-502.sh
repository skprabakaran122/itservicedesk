#!/bin/bash

echo "=== Diagnosing 502 Bad Gateway Issue ==="
echo ""

echo "1. Checking PM2 status..."
pm2 status

echo ""
echo "2. Checking if port 5000 is listening..."
netstat -tlnp | grep :5000 || echo "Port 5000 not listening"

echo ""
echo "3. Checking nginx configuration..."
nginx -t

echo ""
echo "4. Checking nginx status..."
systemctl status nginx --no-pager

echo ""
echo "5. Testing direct connection to app..."
curl -I http://localhost:5000 2>/dev/null || echo "Cannot connect to localhost:5000"

echo ""
echo "6. Checking PM2 logs (last 20 lines)..."
pm2 logs servicedesk --lines 20 --nostream

echo ""
echo "7. Checking for any node processes..."
ps aux | grep node | grep -v grep

echo ""
echo "8. Checking nginx error logs..."
tail -10 /var/log/nginx/error.log 2>/dev/null || echo "No nginx error log found"

echo ""
echo "=== Diagnosis Complete ==="