#!/bin/bash

# Complete cleanup of all IT Service Desk components
echo "=== Complete IT Service Desk Cleanup ==="
echo "This will remove ALL existing installations"
echo ""

# Confirmation
read -p "Are you sure? Type 'DELETE ALL' to continue: " confirm
if [[ $confirm != "DELETE ALL" ]]; then
    echo "Cleanup cancelled"
    exit 0
fi

echo "Starting complete cleanup..."

# 1. Stop all processes
echo "1. Stopping all processes..."
pm2 delete all 2>/dev/null || true
pm2 kill 2>/dev/null || true
sudo pkill -f "servicedesk" 2>/dev/null || true
sudo pkill -f "tsx.*server" 2>/dev/null || true
sudo systemctl stop servicedesk 2>/dev/null || true
sudo systemctl stop nginx 2>/dev/null || true

# 2. Remove systemd services
echo "2. Removing systemd services..."
sudo systemctl disable servicedesk 2>/dev/null || true
sudo rm -f /etc/systemd/system/servicedesk.service
sudo systemctl daemon-reload

# 3. Remove application files
echo "3. Removing application files..."
sudo rm -rf /var/www/servicedesk
sudo rm -rf /var/log/servicedesk
sudo rm -rf /opt/servicedesk
sudo rm -rf /home/*/servicedesk*

# 4. Remove Nginx configuration
echo "4. Removing Nginx configuration..."
sudo rm -f /etc/nginx/sites-enabled/servicedesk*
sudo rm -f /etc/nginx/sites-available/servicedesk*
sudo rm -rf /etc/nginx/ssl/servicedesk*

# 5. Remove database
echo "5. Removing database..."
sudo -u postgres psql << 'EOF' 2>/dev/null || true
DROP DATABASE IF EXISTS servicedesk;
DROP USER IF EXISTS servicedesk;
\q
EOF

# 6. Remove cron jobs
echo "6. Removing cron jobs..."
crontab -l 2>/dev/null | grep -v servicedesk | crontab - 2>/dev/null || true
sudo crontab -l 2>/dev/null | grep -v servicedesk | sudo crontab - 2>/dev/null || true

# 7. Remove PM2 processes and config
echo "7. Cleaning PM2..."
rm -rf ~/.pm2 2>/dev/null || true
sudo rm -rf /home/*/.pm2 2>/dev/null || true

# 8. Remove Node.js global packages (optional)
echo "8. Removing global Node.js packages..."
sudo npm uninstall -g pm2 tsx 2>/dev/null || true

# 9. Clean package caches
echo "9. Cleaning package caches..."
sudo apt autoremove -y 2>/dev/null || true
sudo apt autoclean 2>/dev/null || true

# 10. Remove backup files
echo "10. Removing backup files..."
sudo rm -f /var/backups/servicedesk*
sudo rm -f /tmp/servicedesk*

echo ""
echo "✅ Complete cleanup finished!"
echo "All IT Service Desk components have been removed."
echo "System is ready for fresh installation."