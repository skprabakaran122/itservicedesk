#!/bin/bash

# Complete fix for 502 Bad Gateway error
set -e

echo "=== Fixing 502 Bad Gateway Error ==="

# Check if we're in the right directory
if [ ! -f "server-production.cjs" ]; then
    echo "Error: server-production.cjs not found. Please run from /var/www/itservicedesk"
    exit 1
fi

echo "1. Stopping existing service..."
systemctl stop itservicedesk || echo "Service already stopped"

echo "2. Checking if server-production.cjs exists and is executable..."
ls -la server-production.cjs
chmod +x server-production.cjs

echo "3. Testing server directly..."
echo "Starting server in background for testing..."
node server-production.cjs &
SERVER_PID=$!
sleep 3

echo "4. Testing if server responds on port 3000..."
if curl -f http://localhost:3000 >/dev/null 2>&1; then
    echo "✓ Server responds on port 3000"
    kill $SERVER_PID
else
    echo "✗ Server not responding on port 3000"
    kill $SERVER_PID || true
    
    echo "5. Checking for Node.js and dependencies..."
    node --version
    npm --version
    
    echo "6. Installing dependencies if needed..."
    npm install --production
    
    echo "7. Trying server again..."
    node server-production.cjs &
    SERVER_PID=$!
    sleep 5
    
    if curl -f http://localhost:3000 >/dev/null 2>&1; then
        echo "✓ Server now responds on port 3000"
        kill $SERVER_PID
    else
        echo "✗ Server still not responding"
        kill $SERVER_PID || true
        echo "Checking server logs..."
        node server-production.cjs 2>&1 | head -20
        exit 1
    fi
fi

echo "8. Updating systemd service configuration..."
cat > /etc/systemd/system/itservicedesk.service << 'EOF'
[Unit]
Description=IT Service Desk Application
After=network.target postgresql.service

[Service]
Type=simple
User=root
WorkingDirectory=/var/www/itservicedesk
ExecStart=/usr/bin/node server-production.cjs
Restart=always
RestartSec=10
Environment=NODE_ENV=production
Environment=PORT=3000

[Install]
WantedBy=multi-user.target
EOF

echo "9. Reloading systemd and starting service..."
systemctl daemon-reload
systemctl enable itservicedesk
systemctl start itservicedesk

echo "10. Waiting for service to start..."
sleep 5

echo "11. Checking service status..."
systemctl status itservicedesk --no-pager

echo "12. Verifying port 3000 is listening..."
netstat -tlnp | grep :3000

echo "13. Testing application response..."
curl -I http://localhost:3000

echo "14. Restarting nginx..."
systemctl restart nginx

echo ""
echo "=== Fix Complete ==="
echo "✓ Service should now be running on port 3000"
echo "✓ Nginx should be able to proxy requests"
echo "✓ Your application should be accessible at http://98.81.235.7"
echo ""
echo "If still having issues, check logs with:"
echo "sudo journalctl -u itservicedesk -f"