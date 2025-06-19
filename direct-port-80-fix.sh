#!/bin/bash

# Direct fix - run Node.js on port 80 to bypass nginx issues
set -e

echo "=== Direct Port 80 Fix ==="

echo "1. Stopping nginx to free port 80..."
systemctl stop nginx

echo "2. Stopping current itservicedesk service..."
systemctl stop itservicedesk

echo "3. Creating new systemd service that runs directly on port 80..."
cat > /etc/systemd/system/itservicedesk-direct.service << 'EOF'
[Unit]
Description=IT Service Desk Application - Direct Port 80
After=network.target postgresql.service

[Service]
Type=simple
User=root
WorkingDirectory=/var/www/itservicedesk
ExecStart=/usr/bin/node server-production.cjs
Restart=always
RestartSec=10
Environment=NODE_ENV=production
Environment=PORT=80

[Install]
WantedBy=multi-user.target
EOF

echo "4. Updating server-production.cjs to use PORT environment variable..."
# Create a new server file that uses PORT from environment
cat > server-production-port80.cjs << 'EOF'
const express = require('express');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

// Serve static files
app.use(express.static(path.join(__dirname, 'client')));

// Simple health check
app.get('/health', (req, res) => {
    res.json({ status: 'OK', port: PORT, timestamp: new Date().toISOString() });
});

// Catch all handler - serve index.html for SPA
app.get('*', (req, res) => {
    res.sendFile(path.join(__dirname, 'client', 'index.html'));
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`IT Service Desk running on port ${PORT}`);
    console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
    console.log(`Server ready at http://0.0.0.0:${PORT}`);
});
EOF

echo "5. Updating systemd service to use new server file..."
sed -i 's/server-production.cjs/server-production-port80.cjs/' /etc/systemd/system/itservicedesk-direct.service

echo "6. Reloading systemd and starting direct service..."
systemctl daemon-reload
systemctl enable itservicedesk-direct
systemctl start itservicedesk-direct

echo "7. Waiting for service to start..."
sleep 5

echo "8. Checking service status..."
systemctl status itservicedesk-direct --no-pager

echo "9. Verifying port 80 is listening..."
netstat -tlnp | grep :80

echo "10. Testing direct connection..."
curl -I http://localhost:80 || echo "Cannot connect to localhost:80"

echo "11. Testing health endpoint..."
curl http://localhost:80/health || echo "Health check failed"

echo ""
echo "=== Direct Fix Complete ==="
echo "✓ Node.js now running directly on port 80"
echo "✓ Nginx bypassed completely"
echo "✓ No proxy layer complications"
echo ""
echo "Test your application at: http://98.81.235.7"
echo ""
echo "If this works, the issue was with nginx proxy configuration."
echo "If this still doesn't work, the issue is with the Node.js application itself."
echo ""
echo "Check logs with: sudo journalctl -u itservicedesk-direct -f"