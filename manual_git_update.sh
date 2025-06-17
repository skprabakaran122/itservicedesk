#!/bin/bash

# Manual git update for production server

echo "=== Manual Git Update ==="

cd /var/www/servicedesk

echo "1. Checking git status..."
sudo -u www-data git status

echo "2. Stopping service..."
sudo systemctl stop servicedesk.service

echo "3. Pulling latest changes..."
sudo -u www-data git pull origin main

echo "4. Installing dependencies..."
sudo -u www-data npm install

echo "5. Building application..."
sudo -u www-data npm run build

echo "6. Setting up client files..."
sudo -u www-data mkdir -p server/public
if [ -d "dist/public" ]; then
    sudo -u www-data cp -r dist/public/* server/public/
elif [ -d "dist" ]; then
    sudo -u www-data cp -r dist/* server/public/
fi

echo "7. Adding BASE_URL for production email links..."
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s api.ipify.org)
if ! grep -q "BASE_URL=" .env; then
    echo "BASE_URL=https://$SERVER_IP" | sudo -u www-data tee -a .env
    echo "Added BASE_URL=https://$SERVER_IP"
else
    sudo -u www-data sed -i "s|BASE_URL=.*|BASE_URL=https://$SERVER_IP|" .env
    echo "Updated BASE_URL=https://$SERVER_IP"
fi

echo "8. Starting service..."
sudo systemctl start servicedesk.service

echo "9. Waiting for startup..."
sleep 8

echo "10. Service status:"
sudo systemctl status servicedesk.service --no-pager

echo ""
echo "=== Update Complete ==="
echo "Service desk updated with latest email URL fixes"
echo "Approval links now use: https://$SERVER_IP"