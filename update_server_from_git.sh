#!/bin/bash

# Update production server with latest git changes

echo "=== Updating Service Desk from Git Repository ==="

# Method 1: Use the built-in update script (if it exists)
if [ -f "/usr/local/bin/update-servicedesk" ]; then
    echo "Using built-in update script..."
    sudo /usr/local/bin/update-servicedesk
else
    echo "Built-in update script not found, updating manually..."
    
    cd /var/www/servicedesk
    
    echo "1. Stopping service..."
    sudo systemctl stop servicedesk.service
    
    echo "2. Pulling latest changes from git..."
    sudo -u www-data git pull origin main
    
    echo "3. Installing dependencies..."
    sudo -u www-data npm install
    
    echo "4. Building application..."
    sudo -u www-data npm run build
    
    echo "5. Setting up client build structure..."
    sudo -u www-data mkdir -p server/public
    if [ -d "dist/public" ]; then
        sudo -u www-data cp -r dist/public/* server/public/
    elif [ -d "dist" ]; then
        sudo -u www-data cp -r dist/* server/public/
    fi
    
    echo "6. Updating database schema..."
    sudo -u www-data npm run db:push
    
    echo "7. Adding production BASE_URL if missing..."
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s api.ipify.org)
    if ! grep -q "BASE_URL=" .env; then
        echo "BASE_URL=https://$SERVER_IP" | sudo -u www-data tee -a .env
        echo "Added BASE_URL to environment"
    fi
    
    echo "8. Starting service..."
    sudo systemctl start servicedesk.service
    
    echo "9. Checking service status..."
    sleep 5
    sudo systemctl status servicedesk.service --no-pager
fi

echo ""
echo "=== Update Complete ==="
echo "Your service desk has been updated with the latest changes"
echo "Email approval links will now use the correct production URL"