#!/bin/bash

# Fix tsx path and get the service working

echo "=== Fixing tsx path for systemd service ==="

cd /var/www/servicedesk

# Stop the service
sudo systemctl stop servicedesk.service

# Find where tsx is actually installed
TSX_PATH=$(which tsx)
NPX_PATH=$(which npx)

echo "tsx found at: $TSX_PATH"
echo "npx found at: $NPX_PATH"

if [ -z "$TSX_PATH" ]; then
    echo "tsx not found globally, using npx instead..."
    EXEC_CMD="$NPX_PATH tsx server/index.ts"
else
    echo "Using global tsx installation..."
    EXEC_CMD="$TSX_PATH server/index.ts"
fi

echo "Using command: $EXEC_CMD"

# Update service with correct path
sudo tee /etc/systemd/system/servicedesk.service << EOF
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
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ExecStart=$EXEC_CMD
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=servicedesk

[Install]
WantedBy=multi-user.target
EOF

# Reload and start
sudo systemctl daemon-reload
sudo systemctl start servicedesk.service

echo "Waiting for service to start..."
sleep 10

echo "Service status:"
sudo systemctl status servicedesk.service --no-pager

echo ""
echo "Testing application response:"
curl -s -I http://localhost:5000 | head -3 || echo "No response yet"

echo ""
echo "Recent logs:"
sudo journalctl -u servicedesk.service --no-pager -n 5

echo ""
echo "If still not working, check: sudo journalctl -fu servicedesk"