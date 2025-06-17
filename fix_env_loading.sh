#!/bin/bash

# Fix environment variable loading

echo "=== Debugging Environment Variable Loading ==="

cd /var/www/servicedesk

# Stop the service
sudo systemctl stop servicedesk.service

echo "Checking .env file content and format:"
sudo -u www-data cat .env
echo ""

echo "Extracting DATABASE_URL manually:"
DATABASE_URL=$(sudo -u www-data grep "DATABASE_URL=" .env | head -1 | cut -d= -f2- | tr -d '"' | tr -d "'")
echo "Extracted DATABASE_URL length: ${#DATABASE_URL}"
echo "First 50 chars: ${DATABASE_URL:0:50}..."

# Test different ways to load the environment
echo ""
echo "Testing environment loading methods:"

echo "Method 1: Export and run"
sudo -u www-data bash -c "export DATABASE_URL='$DATABASE_URL' && echo 'DATABASE_URL set to: ${DATABASE_URL:0:50}...' && tsx server/index.ts" &
TEST1_PID=$!
sleep 5

if kill -0 $TEST1_PID 2>/dev/null; then
    echo "✓ Method 1 worked!"
    kill $TEST1_PID
    METHOD_WORKS=1
else
    echo "✗ Method 1 failed"
    wait $TEST1_PID
    METHOD_WORKS=0
fi

if [ $METHOD_WORKS -eq 1 ]; then
    echo ""
    echo "Updating systemd service with explicit DATABASE_URL:"
    
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
Environment=DATABASE_URL=$DATABASE_URL
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

    echo "Reloading and starting service..."
    sudo systemctl daemon-reload
    sudo systemctl start servicedesk.service
    
    sleep 8
    
    echo "Service status:"
    sudo systemctl status servicedesk.service --no-pager
    
    echo ""
    echo "Testing HTTP response:"
    curl -s -I http://localhost:5000 | head -3 || echo "No response yet"
    
    echo ""
    echo "Recent logs:"
    sudo journalctl -u servicedesk.service --no-pager -n 10
    
else
    echo "Environment loading failed - need to check .env format"
fi