#!/bin/bash

# Diagnose and fix 502 Bad Gateway error
set -e

echo "=== Diagnosing 502 Bad Gateway Error ==="
echo ""

echo "1. Checking IT Service Desk service status..."
systemctl status itservicedesk --no-pager || echo "Service not running properly"
echo ""

echo "2. Checking if port 3000 is listening..."
netstat -tlnp | grep :3000 || echo "No process listening on port 3000"
echo ""

echo "3. Checking recent service logs..."
journalctl -u itservicedesk --no-pager -n 20
echo ""

echo "4. Checking nginx configuration..."
nginx -t
echo ""

echo "5. Checking nginx error logs..."
tail -20 /var/log/nginx/error.log || echo "No error log found"
echo ""

echo "=== Attempting to restart services ==="

echo "Restarting IT Service Desk service..."
systemctl restart itservicedesk
sleep 5

echo "Checking service status after restart..."
systemctl status itservicedesk --no-pager

echo ""
echo "Checking if port 3000 is now listening..."
netstat -tlnp | grep :3000 || echo "Still no process on port 3000"

echo ""
echo "Testing local connection to port 3000..."
curl -I http://localhost:3000 || echo "Cannot connect to localhost:3000"

echo ""
echo "=== Diagnosis Complete ==="