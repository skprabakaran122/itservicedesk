#!/bin/bash

cd /var/www/itservicedesk

echo "=== Diagnosing 502 Bad Gateway ==="

echo "1. PM2 Status:"
pm2 status

echo ""
echo "2. PM2 Logs (last 20 lines):"
pm2 logs servicedesk --lines 20 --nostream 2>/dev/null || echo "No PM2 logs available"

echo ""
echo "3. Checking port 5000:"
netstat -tlnp | grep :5000 2>/dev/null || ss -tlnp | grep :5000 2>/dev/null || echo "Port 5000 not listening"

echo ""
echo "4. Testing direct connection:"
curl -v http://localhost:5000 2>&1 | head -10

echo ""
echo "5. Checking server.js exists and is valid:"
ls -la server.js
node -c server.js && echo "✓ server.js syntax OK" || echo "✗ server.js syntax error"

echo ""
echo "6. Testing database connection:"
sudo -u postgres psql -d servicedesk -c "SELECT 1;" 2>/dev/null && echo "✓ Database accessible" || echo "✗ Database connection failed"

echo ""
echo "=== Attempting Fix ==="

# Stop PM2 completely
pm2 delete all 2>/dev/null || true
pm2 kill

# Test server.js directly
echo "Testing server.js directly..."
timeout 15s node server.js &
SERVER_PID=$!
sleep 8

if curl -s http://localhost:5000 > /dev/null 2>&1; then
    echo "✓ server.js works directly"
    kill $SERVER_PID 2>/dev/null || true
    
    # Start with PM2
    echo "Starting with PM2..."
    pm2 start ecosystem.config.cjs
    sleep 10
    pm2 status
    
    # Test again
    if curl -s http://localhost:5000 > /dev/null 2>&1; then
        echo "✓ Application running successfully"
        
        # Fix nginx
        echo "Fixing nginx configuration..."
        systemctl restart nginx
        sleep 3
        
        echo "Final test through nginx:"
        curl -I http://localhost 2>/dev/null || echo "Nginx still not working"
        
    else
        echo "✗ PM2 start failed"
        pm2 logs servicedesk --lines 10
    fi
    
else
    echo "✗ server.js failed directly"
    kill $SERVER_PID 2>/dev/null || true
    
    # Check for errors
    echo "Checking for Node.js errors..."
    node server.js 2>&1 | head -20
fi

echo ""
echo "=== Diagnosis Complete ==="