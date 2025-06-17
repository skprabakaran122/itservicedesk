#!/bin/bash

# Clean and Deploy IT Service Desk
# This script removes existing installations and performs a fresh deployment

set -e

echo "==============================================="
echo "IT Service Desk - Clean Installation"
echo "==============================================="
echo ""

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo "Please run this script as a regular user with sudo privileges, not as root"
   exit 1
fi

echo "⚠️  WARNING: This will remove ALL existing Service Desk installations!"
echo "This includes:"
echo "- Application files in /var/www/servicedesk"
echo "- Database 'servicedesk' and user 'servicedesk'"
echo "- Nginx configuration"
echo "- PM2 processes"
echo "- Log files"
echo ""
read -p "Are you sure you want to proceed? Type 'YES' to continue: " confirm

if [[ $confirm != "YES" ]]; then
    echo "Operation cancelled"
    exit 0
fi

echo ""
echo "Starting cleanup process..."

# Stop and remove PM2 processes
echo "1. Stopping PM2 processes..."
pm2 delete servicedesk 2>/dev/null || echo "No PM2 process 'servicedesk' found"
pm2 delete all 2>/dev/null || echo "No PM2 processes to stop"
pm2 kill 2>/dev/null || echo "PM2 daemon not running"

# Stop and remove systemd services
echo "2. Stopping system services..."
sudo systemctl stop servicedesk 2>/dev/null || echo "No systemd service 'servicedesk' found"
sudo systemctl disable servicedesk 2>/dev/null || echo "Service 'servicedesk' not enabled"
sudo rm -f /etc/systemd/system/servicedesk.service
sudo systemctl daemon-reload

# Remove Nginx configuration
echo "3. Removing Nginx configuration..."
sudo rm -f /etc/nginx/sites-enabled/servicedesk
sudo rm -f /etc/nginx/sites-available/servicedesk
sudo rm -rf /etc/nginx/ssl/servicedesk.*
sudo nginx -t && sudo systemctl restart nginx || echo "Nginx configuration cleaned"

# Remove application directory
echo "4. Removing application files..."
sudo rm -rf /var/www/servicedesk
sudo rm -rf /var/log/servicedesk

# Remove database
echo "5. Cleaning database..."
sudo -u postgres psql << 'EOF' 2>/dev/null || echo "Database cleanup completed"
DROP DATABASE IF EXISTS servicedesk;
DROP USER IF EXISTS servicedesk;
\q
EOF

# Remove cron jobs
echo "6. Removing scheduled tasks..."
crontab -l 2>/dev/null | grep -v "/var/www/servicedesk" | crontab - 2>/dev/null || echo "No cron jobs to remove"

# Remove any Node.js processes
echo "7. Stopping Node.js processes..."
sudo pkill -f "servicedesk" 2>/dev/null || echo "No servicedesk processes running"
sudo pkill -f "tsx.*server/index.ts" 2>/dev/null || echo "No tsx processes running"

# Clean up any remaining files
echo "8. Final cleanup..."
sudo rm -f /var/backups/servicedesk_*
sudo rm -f /tmp/servicedesk*

echo ""
echo "✅ Cleanup completed successfully!"
echo ""

# Now run the deployment
echo "Starting fresh deployment..."
echo ""

# Check if deploy script exists
if [ ! -f "deploy1.sh" ]; then
    echo "❌ deploy_to_server.sh not found in current directory"
    echo "Please ensure the deployment script is in the same directory as this script"
    exit 1
fi

# Make deploy script executable
chmod +x deploy1.sh

# Run deployment
echo "Executing deployment script..."
./deploy1.sh

echo ""
echo "==============================================="
echo "Clean deployment completed!"
echo "==============================================="