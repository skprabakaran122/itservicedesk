#!/bin/bash

# Fix permissions and start the application directly

echo "=== Fixing Permissions and Starting Application ==="

cd /var/www/servicedesk

# Stop any running services
sudo systemctl stop servicedesk.service pm2-servicedesk.service || true

echo "Fixing ownership and permissions..."
sudo chown -R www-data:www-data /var/www/servicedesk
sudo chmod -R u+w /var/www/servicedesk

echo "Cleaning and reinstalling dependencies..."
sudo -u www-data rm -rf node_modules package-lock.json
sudo -u www-data npm install

echo "Creating simple production service..."
sudo tee /etc/systemd/system/servicedesk.service << 'EOF'
[Unit]
Description=Calpion IT Service Desk
After=network.target postgresql.service
Wants=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/var/www/servicedesk
Environment=NODE_ENV=production
Environment=PORT=5000
Environment=HOST=127.0.0.1
ExecStart=/usr/bin/node --loader tsx/esm server/index.ts
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=servicedesk

[Install]
WantedBy=multi-user.target
EOF

echo "Starting service..."
sudo systemctl daemon-reload
sudo systemctl enable servicedesk.service
sudo systemctl start servicedesk.service

sleep 8
echo "Checking service status..."
sudo systemctl status servicedesk.service --no-pager

echo ""
echo "Checking logs..."
sudo journalctl -u servicedesk.service --no-pager -n 10

echo ""
echo "Testing application..."
curl -s -I http://localhost:5000 | head -5 || echo "Service not responding"

echo ""
echo "=== Next Steps ==="
echo "If the service is running, your app should be accessible via Nginx"
echo "Check logs: sudo journalctl -fu servicedesk"
echo "Manual start test: cd /var/www/servicedesk && sudo -u www-data node --loader tsx/esm server/index.ts"