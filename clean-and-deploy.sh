#!/bin/bash

echo "IT Service Desk - Clean Installation Script"
echo "==========================================="

# Exit on any error
set -e

# Configuration
DB_NAME="servicedesk"
DB_USER="servicedesk"

echo "Starting clean installation process..."

# 1. Stop existing services
echo "1. Stopping existing services..."

# Stop PM2 processes
if command -v pm2 >/dev/null 2>&1; then
    echo "Stopping PM2 processes..."
    pm2 kill || true
fi

# Stop Nginx
sudo systemctl stop nginx || true

# Stop PostgreSQL
sudo systemctl stop postgresql || true

echo "Services stopped"

# 2. Remove existing configurations
echo "2. Removing existing configurations..."

# Remove Nginx configurations
sudo rm -f /etc/nginx/sites-enabled/$DB_NAME
sudo rm -f /etc/nginx/sites-available/$DB_NAME
sudo rm -rf /etc/nginx/ssl

# Remove PM2 configurations
if [ -f ecosystem.config.js ]; then
    rm -f ecosystem.config.js
fi

# Remove logs
rm -rf logs

# Remove build artifacts
rm -rf dist
rm -rf node_modules

echo "Configurations removed"

# 3. Clean database
echo "3. Cleaning database..."

# Start PostgreSQL to clean it
sudo systemctl start postgresql

# Drop database and user if they exist
sudo -u postgres psql << EOF || true
DROP DATABASE IF EXISTS $DB_NAME;
DROP USER IF EXISTS $DB_USER;
\q
EOF

# Stop PostgreSQL again
sudo systemctl stop postgresql

echo "Database cleaned"

# 4. Remove all packages completely
echo "4. Removing all packages completely..."

# Remove PM2 globally
sudo npm uninstall -g pm2 || true

# Remove Node.js and all related packages
sudo apt remove --purge -y nodejs npm node-* || true
sudo rm -rf /usr/local/bin/node
sudo rm -rf /usr/local/bin/npm
sudo rm -rf /usr/local/lib/node_modules
sudo rm -rf /etc/apt/sources.list.d/nodesource.list*

# Remove PostgreSQL completely
sudo apt remove --purge -y postgresql* || true
sudo rm -rf /etc/postgresql/
sudo rm -rf /var/lib/postgresql/
sudo rm -rf /var/log/postgresql/
sudo deluser postgres || true
sudo delgroup postgres || true

# Remove Nginx completely
sudo apt remove --purge -y nginx* || true
sudo rm -rf /etc/nginx/
sudo rm -rf /var/log/nginx/
sudo rm -rf /var/www/html/

# Remove build tools and dependencies
sudo apt remove --purge -y build-essential curl wget gnupg2 software-properties-common apt-transport-https ca-certificates || true

# Clean package cache thoroughly
sudo apt autoremove --purge -y
sudo apt autoclean
sudo apt clean

# Clear dpkg cache
sudo rm -rf /var/cache/apt/archives/*

echo "All packages removed completely"

# 5. Deep clean all configurations and caches
echo "5. Deep cleaning all configurations and caches..."

# Remove all Node.js and npm related files
rm -rf ~/.npm
rm -rf ~/.node-gyp
rm -rf ~/.config/configstore/
sudo rm -rf /root/.npm
sudo rm -rf /root/.node-gyp

# Remove any remaining Node.js installations
sudo rm -rf /opt/node*
sudo rm -rf /usr/share/node*

# Clean systemd services
sudo rm -f /etc/systemd/system/servicedesk.service
sudo systemctl daemon-reload

# Remove any PM2 startup scripts
sudo rm -f /etc/systemd/system/pm2*.service

# Clean log files
sudo rm -rf /var/log/nginx*
sudo rm -rf /var/log/postgresql*
sudo find /var/log -name "*servicedesk*" -delete

# Remove certificates and SSL
sudo rm -rf /etc/ssl/certs/servicedesk*
sudo rm -rf /etc/ssl/private/servicedesk*

# Clean home directory artifacts
rm -rf ~/.pm2
rm -rf ~/.cache/

echo "Deep cleaning completed"

# 6. Reset firewall (optional - commented out for safety)
echo "6. Firewall status (not resetting for safety)..."
sudo ufw status

# 7. Final system cleanup and verification
echo "7. Performing final system cleanup..."

# Kill any remaining processes
sudo pkill -f node || true
sudo pkill -f nginx || true
sudo pkill -f postgres || true

# Remove any remaining socket files
sudo rm -f /tmp/.s.PGSQL.* || true
sudo rm -f /var/run/postgresql/.s.PGSQL.* || true

# Clean package database
sudo dpkg --configure -a
sudo apt-get -f install

# Update package lists
sudo apt update

# Final cleanup
sudo apt-get autoremove --purge -y
sudo apt-get autoclean
sudo apt clean

# Reset package manager state
sudo apt-mark showhold | xargs sudo apt-mark unhold || true

# Verify clean state
echo ""
echo "Verifying clean state..."
echo "Node.js: $(command -v node || echo 'REMOVED')"
echo "npm: $(command -v npm || echo 'REMOVED')"
echo "PostgreSQL: $(command -v psql || echo 'REMOVED')"
echo "Nginx: $(command -v nginx || echo 'REMOVED')"
echo "PM2: $(command -v pm2 || echo 'REMOVED')"

echo "System completely cleaned and verified"

# 8. Run deployment
echo "8. Starting fresh deployment..."
echo ""

# Make sure deploy script is executable
chmod +x deploy.sh

# Run the deployment script
echo "Running deploy.sh..."
sudo ./deploy.sh

echo ""
echo "🎉 CLEAN INSTALLATION COMPLETE!"
echo "=========================================="
echo "The system has been cleaned and redeployed successfully."