#!/bin/bash

# Debug blank page issue - check what's actually being served
set -e

echo "=== Debugging Blank Page Issue ==="

cd /var/www/itservicedesk

echo "1. Checking service status..."
systemctl status itservicedesk --no-pager | head -10

echo "2. Checking what files exist..."
ls -la
echo ""
echo "Client directory contents:"
ls -la client/ 2>/dev/null || echo "No client directory"

echo "3. Testing direct server response..."
echo "Root path response:"
curl -s http://localhost:5000/ | head -20

echo ""
echo "4. Testing health endpoint..."
curl -s http://localhost:5000/health

echo ""
echo "5. Checking nginx response..."
curl -s http://localhost:80/ | head -20

echo ""
echo "6. Checking server logs for errors..."
journalctl -u itservicedesk --no-pager -n 10

echo ""
echo "7. Checking nginx error logs..."
tail -5 /var/log/nginx/error.log 2>/dev/null || echo "No nginx errors"

echo ""
echo "=== Debug Complete ==="