#!/bin/bash

# Fix the build and dependency issue

echo "=== Fixing Build and Dependencies ==="

cd /var/www/servicedesk

# Stop any running services
sudo systemctl stop servicedesk.service pm2-servicedesk.service || true

echo "Installing all dependencies..."
sudo -u www-data npm ci

echo "Rebuilding application with proper bundling..."
sudo -u www-data npm run build

# Check if the build was successful
if [ ! -f "dist/index.js" ]; then
    echo "Build failed - checking for alternative build output..."
    ls -la dist/
    exit 1
fi

echo "Checking build output for external dependencies..."
head -20 dist/index.js

# Don't remove dev dependencies yet - keep them for runtime
echo "Keeping all dependencies for now..."

# Update service to run from TypeScript directly if build is problematic
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
ExecStart=/usr/bin/npx tsx server/index.ts
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=servicedesk

# Security
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=/var/www/servicedesk/uploads

[Install]
WantedBy=multi-user.target
EOF

# Reload and start the service
sudo systemctl daemon-reload
sudo systemctl enable servicedesk.service
sudo systemctl start servicedesk.service

echo "Waiting for service to start..."
sleep 5

echo "Checking service status..."
sudo systemctl status servicedesk.service

echo "Testing application response..."
sleep 5
curl -s -I http://localhost:5000 || echo "No response on port 5000"

echo ""
echo "=== Service Management Commands ==="
echo "Status:  sudo systemctl status servicedesk"
echo "Logs:    sudo journalctl -fu servicedesk"
echo "Restart: sudo systemctl restart servicedesk"
echo ""
echo "If still failing, check: sudo journalctl -fu servicedesk --no-pager -n 50"