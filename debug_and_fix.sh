#!/bin/bash

# Debug and fix the application startup issue

echo "=== Debugging Application Startup ==="

# Check the current directory structure
echo "Checking application directory..."
cd /var/www/servicedesk
pwd
ls -la

echo ""
echo "Checking dist directory..."
ls -la dist/ || echo "No dist directory found"

echo ""
echo "Checking if we can run the app manually..."
cd /var/www/servicedesk
sudo -u www-data NODE_ENV=production /usr/bin/node dist/index.js &
APP_PID=$!
sleep 5

# Check if the process is running
if kill -0 $APP_PID 2>/dev/null; then
    echo "Application started successfully!"
    kill $APP_PID
else
    echo "Application failed to start"
fi

echo ""
echo "Checking application logs..."
sudo journalctl -fu pm2-servicedesk.service --no-pager -n 20

echo ""
echo "=== Fixing Service Configuration ==="

# Stop the service
sudo systemctl stop pm2-servicedesk.service

# Create an improved service file
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
ExecStart=/usr/bin/node dist/index.js
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

# Reload and start the new service
sudo systemctl daemon-reload
sudo systemctl disable pm2-servicedesk.service
sudo systemctl enable servicedesk.service
sudo systemctl start servicedesk.service

echo ""
echo "Checking new service status..."
sleep 3
sudo systemctl status servicedesk.service

echo ""
echo "Checking if the application is responding..."
sleep 5
curl -s http://localhost:5000 | head -10 || echo "Application not responding on port 5000"

echo ""
echo "Service management commands:"
echo "  Status:  sudo systemctl status servicedesk"
echo "  Start:   sudo systemctl start servicedesk"
echo "  Stop:    sudo systemctl stop servicedesk"
echo "  Restart: sudo systemctl restart servicedesk"
echo "  Logs:    sudo journalctl -fu servicedesk"