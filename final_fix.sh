#!/bin/bash

# Final fix for npm permissions and application startup

echo "=== Final Fix for Service Desk Application ==="

cd /var/www/servicedesk

# Stop all services
sudo systemctl stop servicedesk.service pm2-servicedesk.service || true

echo "Fixing npm cache permissions..."
sudo chown -R 33:33 "/var/www/.npm" || sudo rm -rf /var/www/.npm
sudo mkdir -p /var/www/.npm
sudo chown -R www-data:www-data /var/www/.npm

echo "Fixing application permissions..."
sudo chown -R www-data:www-data /var/www/servicedesk
sudo chmod -R 755 /var/www/servicedesk

echo "Installing dependencies as www-data user..."
sudo -u www-data npm cache clean --force
sudo -u www-data npm install

echo "Installing tsx globally for TypeScript execution..."
sudo npm install -g tsx

echo "Creating production service with global tsx..."
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
ExecStart=/usr/local/bin/tsx server/index.ts
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=servicedesk

[Install]
WantedBy=multi-user.target
EOF

echo "Testing manual startup first..."
cd /var/www/servicedesk
sudo -u www-data NODE_ENV=production PORT=5000 /usr/local/bin/tsx server/index.ts &
TEST_PID=$!
sleep 10

# Check if it's running
if kill -0 $TEST_PID 2>/dev/null; then
    echo "✓ Manual test successful - killing test process"
    kill $TEST_PID
    
    echo "Starting systemd service..."
    sudo systemctl daemon-reload
    sudo systemctl enable servicedesk.service
    sudo systemctl start servicedesk.service
    
    sleep 8
    echo "Service status:"
    sudo systemctl status servicedesk.service --no-pager
    
    echo ""
    echo "Testing HTTP response..."
    curl -s -I http://localhost:5000 | head -3 || echo "No HTTP response"
    
else
    echo "✗ Manual test failed - checking error"
    wait $TEST_PID
    echo "Exit code: $?"
fi

echo ""
echo "=== Application Management ==="
echo "Start:    sudo systemctl start servicedesk"
echo "Stop:     sudo systemctl stop servicedesk" 
echo "Status:   sudo systemctl status servicedesk"
echo "Logs:     sudo journalctl -fu servicedesk"
echo "Manual:   cd /var/www/servicedesk && sudo -u www-data /usr/local/bin/tsx server/index.ts"