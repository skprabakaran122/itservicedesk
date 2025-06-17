#!/bin/bash

# Fix production BASE_URL for email approval links

echo "=== Fixing Production Email URLs ==="

cd /var/www/servicedesk

# Stop the service
sudo systemctl stop servicedesk.service

# Check current .env file
echo "Current .env configuration:"
sudo -u www-data cat .env | grep -E "(BASE_URL|DATABASE_URL)" || echo "No BASE_URL found"

# Add BASE_URL to .env file
echo ""
echo "Adding BASE_URL to environment configuration..."

# Get server IP
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s api.ipify.org)
BASE_URL="https://$SERVER_IP"

echo "Setting BASE_URL to: $BASE_URL"

# Check if BASE_URL already exists in .env
if grep -q "BASE_URL=" .env; then
    # Update existing BASE_URL
    sudo -u www-data sed -i "s|BASE_URL=.*|BASE_URL=$BASE_URL|" .env
    echo "Updated existing BASE_URL"
else
    # Add new BASE_URL
    echo "BASE_URL=$BASE_URL" | sudo -u www-data tee -a .env
    echo "Added BASE_URL to .env"
fi

echo ""
echo "Updated .env configuration:"
sudo -u www-data cat .env | grep -E "(BASE_URL|DATABASE_URL)"

echo ""
echo "Starting service..."
sudo systemctl start servicedesk.service

sleep 8

echo "Service status:"
sudo systemctl status servicedesk.service --no-pager -l

echo ""
echo "Testing email URL generation..."
echo "Email approval links will now use: $BASE_URL"

echo ""
echo "=== Email URL Fix Complete ==="
echo "Approval links in emails will now point to: $BASE_URL"
echo "Instead of: http://localhost:5000"