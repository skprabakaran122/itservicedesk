#!/bin/bash

# Fix environment variables and build issues

echo "=== Fixing Environment and Build Issues ==="

cd /var/www/servicedesk

# Stop the service
sudo systemctl stop servicedesk.service

echo "Checking current .env file:"
cat .env

echo ""
echo "Reading DATABASE_URL from .env:"
DATABASE_URL=$(sudo -u www-data grep "DATABASE_URL=" .env | cut -d= -f2-)
echo "Found DATABASE_URL: ${DATABASE_URL:0:50}..."

# Update systemd service to load .env file
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
EnvironmentFile=/var/www/servicedesk/.env
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ExecStart=/usr/bin/tsx server/index.ts
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=servicedesk

[Install]
WantedBy=multi-user.target
EOF

echo "Building client application..."
sudo -u www-data npm run build

echo "Checking if client build exists:"
ls -la dist/ 2>/dev/null || echo "No dist directory"
ls -la server/public/ 2>/dev/null || echo "No server/public directory"

# Create the expected public directory structure
echo "Creating expected public directory structure..."
sudo -u www-data mkdir -p server/public
if [ -d "dist/public" ]; then
    sudo -u www-data cp -r dist/public/* server/public/
elif [ -d "dist" ]; then
    sudo -u www-data cp -r dist/* server/public/
fi

echo "Testing manual execution with environment:"
sudo -u www-data bash -c "source .env && tsx server/index.ts" &
TEST_PID=$!
sleep 8

if kill -0 $TEST_PID 2>/dev/null; then
    echo "✓ Manual test successful!"
    kill $TEST_PID
    
    echo "Starting systemd service..."
    sudo systemctl daemon-reload
    sudo systemctl start servicedesk.service
    
    sleep 5
    sudo systemctl status servicedesk.service --no-pager
    
    echo ""
    echo "Testing HTTP response:"
    curl -s -I http://localhost:5000 | head -3
    
else
    echo "✗ Manual test failed"
    wait $TEST_PID
fi

echo ""
echo "Service management:"
echo "Status: sudo systemctl status servicedesk"
echo "Logs:   sudo journalctl -fu servicedesk"