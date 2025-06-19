#!/bin/bash

# Simple 502 fix - check what's actually wrong and fix it
set -e

echo "=== Simple 502 Fix ==="

echo "1. Checking what's in the working directory..."
ls -la /var/www/itservicedesk/

echo "2. Checking server-production.cjs content..."
head -20 /var/www/itservicedesk/server-production.cjs

echo "3. Testing server file directly..."
cd /var/www/itservicedesk
node server-production.cjs &
SERVER_PID=$!
sleep 3

echo "4. Checking if server started..."
ps aux | grep $SERVER_PID || echo "Server process not found"

echo "5. Testing server response..."
curl -v http://localhost:3000 2>&1 | head -10 || echo "Server not responding"

echo "6. Killing test server..."
kill $SERVER_PID 2>/dev/null || true

echo "7. Checking for missing files..."
if [ ! -f "client/index.html" ]; then
    echo "Missing client/index.html - creating basic one..."
    mkdir -p client
    cat > client/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>IT Service Desk</title>
</head>
<body>
    <h1>IT Service Desk</h1>
    <p>Application is running</p>
</body>
</html>
EOF
fi

echo "8. Simple nginx config pointing to working server..."
cat > /etc/nginx/sites-available/itservicedesk << 'EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF

echo "9. Restart everything..."
systemctl restart itservicedesk
sleep 3
systemctl restart nginx

echo "10. Final test..."
echo "Service status:"
systemctl status itservicedesk --no-pager | head -10

echo "Port check:"
netstat -tlnp | grep :3000

echo "Nginx test:"
curl -I http://localhost:80

echo "=== Fix Complete ==="