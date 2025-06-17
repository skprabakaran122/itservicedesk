#!/bin/bash

# Fix PM2 service startup issue
set -e

echo "Checking PM2 service status..."
sudo systemctl status pm2-www-data.service || true

echo "Checking PM2 logs..."
sudo journalctl -xeu pm2-www-data.service --no-pager -n 10 || true

echo "Fixing PM2 service configuration..."

# Stop and disable the problematic service
sudo systemctl stop pm2-www-data.service || true
sudo systemctl disable pm2-www-data.service || true

# Create a simpler, working systemd service
sudo tee /etc/systemd/system/pm2-servicedesk.service << 'EOF'
[Unit]
Description=PM2 Service Desk Application
After=network.target
Wants=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/var/www/servicedesk
Environment=NODE_ENV=production
Environment=PM2_HOME=/var/www/.pm2
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ExecStart=/usr/bin/node dist/index.js
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable the new service
sudo systemctl daemon-reload
sudo systemctl enable pm2-servicedesk.service

# Stop any existing PM2 processes
sudo -u www-data PM2_HOME=/var/www/.pm2 pm2 kill || true

# Start the service directly
echo "Starting service..."
sudo systemctl start pm2-servicedesk.service

# Check if it's running
sleep 3
sudo systemctl status pm2-servicedesk.service

echo "Service setup complete!"
echo ""
echo "Management commands:"
echo "  Status:  sudo systemctl status pm2-servicedesk"
echo "  Start:   sudo systemctl start pm2-servicedesk"
echo "  Stop:    sudo systemctl stop pm2-servicedesk"
echo "  Restart: sudo systemctl restart pm2-servicedesk"
echo "  Logs:    sudo journalctl -fu pm2-servicedesk"