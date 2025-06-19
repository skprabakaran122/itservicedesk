#!/bin/bash

# Complete 502 solution - systematic fix of all potential issues
set -e

echo "=== Complete 502 Solution ==="

cd /var/www/itservicedesk || { echo "Directory not found"; exit 1; }

echo "1. Installing essential tools..."
apt-get update -qq && apt-get install -y net-tools curl

echo "2. Checking current server file..."
if [ ! -f "server-production.cjs" ]; then
    echo "Creating server-production.cjs..."
    cat > server-production.cjs << 'EOF'
const express = require('express');
const path = require('path');

const app = express();
const PORT = 3000;

// Basic middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Health check
app.get('/health', (req, res) => {
    res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

// API test endpoint
app.get('/api/test', (req, res) => {
    res.json({ message: 'API working', server: 'production' });
});

// Serve static files if they exist
const clientPath = path.join(__dirname, 'client');
console.log('Looking for client files in:', clientPath);

app.use(express.static(clientPath));

// Fallback for SPA routing
app.get('*', (req, res) => {
    const indexPath = path.join(clientPath, 'index.html');
    if (require('fs').existsSync(indexPath)) {
        res.sendFile(indexPath);
    } else {
        res.send(`
<!DOCTYPE html>
<html>
<head><title>IT Service Desk</title></head>
<body>
    <h1>IT Service Desk</h1>
    <p>Server is running on port ${PORT}</p>
    <p>Time: ${new Date().toISOString()}</p>
    <p><a href="/health">Health Check</a></p>
    <p><a href="/api/test">API Test</a></p>
</body>
</html>
        `);
    }
});

// Error handling
app.use((err, req, res, next) => {
    console.error('Error:', err);
    res.status(500).json({ error: 'Internal server error' });
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`Server running on port ${PORT}`);
    console.log(`Environment: ${process.env.NODE_ENV || 'production'}`);
    console.log(`Time: ${new Date().toISOString()}`);
});
EOF
fi

echo "3. Making server executable..."
chmod +x server-production.cjs

echo "4. Testing server directly..."
timeout 10 node server-production.cjs &
TEST_PID=$!
sleep 3

if curl -f http://localhost:3000/health >/dev/null 2>&1; then
    echo "✓ Server responds correctly"
    kill $TEST_PID 2>/dev/null || true
else
    echo "✗ Server not responding"
    kill $TEST_PID 2>/dev/null || true
    echo "Checking dependencies..."
    npm install express 2>/dev/null || echo "Express installation failed"
fi

echo "5. Creating clean systemd service..."
cat > /etc/systemd/system/itservicedesk.service << 'EOF'
[Unit]
Description=IT Service Desk Application
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/var/www/itservicedesk
ExecStart=/usr/bin/node server-production.cjs
Restart=always
RestartSec=5
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

echo "6. Creating minimal nginx configuration..."
cat > /etc/nginx/sites-available/itservicedesk << 'EOF'
server {
    listen 80 default_server;
    server_name _;
    
    location /health {
        proxy_pass http://127.0.0.1:3000/health;
        proxy_set_header Host $host;
    }
    
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_connect_timeout 30;
        proxy_send_timeout 30;
        proxy_read_timeout 30;
    }
}
EOF

echo "7. Removing conflicting nginx configs..."
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/itservicedesk /etc/nginx/sites-enabled/

echo "8. Testing nginx config..."
nginx -t

echo "9. Starting services in correct order..."
systemctl daemon-reload
systemctl stop nginx 2>/dev/null || true
systemctl stop itservicedesk 2>/dev/null || true

systemctl start itservicedesk
sleep 5

echo "10. Verifying service started..."
systemctl status itservicedesk --no-pager

echo "11. Checking port 3000..."
netstat -tlnp | grep :3000 || echo "Port 3000 not found"

echo "12. Testing application directly..."
curl -f http://localhost:3000/health && echo "✓ Direct connection works"

echo "13. Starting nginx..."
systemctl start nginx

echo "14. Final verification..."
echo "Nginx status:"
systemctl status nginx --no-pager

echo "Testing through nginx:"
curl -f http://localhost:80/health && echo "✓ Nginx proxy works"

echo ""
echo "=== Solution Complete ==="
echo "Your IT Service Desk should now be accessible at:"
echo "http://98.81.235.7"
echo ""
echo "Test endpoints:"
echo "http://98.81.235.7/health"
echo "http://98.81.235.7/api/test"
echo ""
echo "If still having issues, check logs:"
echo "sudo journalctl -u itservicedesk -f"
echo "sudo tail -f /var/log/nginx/error.log"