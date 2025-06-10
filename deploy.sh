#!/bin/bash

# IT Service Desk Deployment Script for Ubuntu
# Run with: bash deploy.sh

set -e

echo "=== IT Service Desk Deployment Script ==="
echo "This will install and configure the IT Service Desk application on Ubuntu"
echo ""

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo "Please do not run this script as root. Use a regular user with sudo privileges."
   exit 1
fi

# Get user inputs
read -p "Enter database password for servicedesk_user: " -s DB_PASSWORD
echo ""
read -p "Enter session secret (32+ characters): " -s SESSION_SECRET
echo ""
read -p "Enter application domain (or IP address): " DOMAIN
read -p "Install Nginx reverse proxy? (y/n): " INSTALL_NGINX

# Update system
echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install dependencies
echo "Installing system dependencies..."
sudo apt install -y curl wget git build-essential

# Install Node.js 20
echo "Installing Node.js 20..."
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Verify Node.js installation
NODE_VERSION=$(node --version)
NPM_VERSION=$(npm --version)
echo "Node.js version: $NODE_VERSION"
echo "NPM version: $NPM_VERSION"

# Install PostgreSQL
echo "Installing PostgreSQL..."
sudo apt install -y postgresql postgresql-contrib

# Start PostgreSQL service
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Create database and user
echo "Setting up database..."
sudo -u postgres psql << EOF
DROP DATABASE IF EXISTS servicedesk;
DROP USER IF EXISTS servicedesk_user;
CREATE DATABASE servicedesk;
CREATE USER servicedesk_user WITH PASSWORD '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE servicedesk TO servicedesk_user;
ALTER USER servicedesk_user CREATEDB;
\q
EOF

# Get current directory
APP_DIR=$(pwd)

# Install application dependencies
echo "Installing application dependencies..."
npm install

# Install global packages
sudo npm install -g tsx typescript pm2

# Create environment file
echo "Creating environment configuration..."
cat > .env << EOF
DATABASE_URL=postgresql://servicedesk_user:$DB_PASSWORD@localhost:5432/servicedesk
NODE_ENV=production
PORT=5000
SESSION_SECRET=$SESSION_SECRET
EOF

# Setup database schema
echo "Setting up database schema..."
npm run db:push

# Create logs directory
mkdir -p logs

# Create PM2 ecosystem file
echo "Creating PM2 configuration..."
cat > ecosystem.config.js << EOF
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'npm',
    args: 'run dev',
    cwd: '$APP_DIR',
    env: {
      NODE_ENV: 'production',
      PORT: 5000
    },
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    error_file: './logs/err.log',
    out_file: './logs/out.log',
    log_file: './logs/combined.log',
    time: true
  }]
};
EOF

# Start application with PM2
echo "Starting application with PM2..."
pm2 start ecosystem.config.js
pm2 save

# Setup PM2 startup
echo "Configuring PM2 startup..."
PM2_STARTUP_CMD=$(pm2 startup | grep "sudo env" | head -1)
if [ ! -z "$PM2_STARTUP_CMD" ]; then
    eval $PM2_STARTUP_CMD
fi

# Install and configure Nginx if requested
if [[ $INSTALL_NGINX == "y" || $INSTALL_NGINX == "Y" ]]; then
    echo "Installing and configuring Nginx..."
    sudo apt install -y nginx
    
    # Create Nginx configuration
    sudo tee /etc/nginx/sites-available/servicedesk << EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF
    
    # Enable site
    sudo ln -sf /etc/nginx/sites-available/servicedesk /etc/nginx/sites-enabled/
    sudo rm -f /etc/nginx/sites-enabled/default
    
    # Test and restart Nginx
    sudo nginx -t && sudo systemctl restart nginx
    sudo systemctl enable nginx
fi

# Configure firewall
echo "Configuring firewall..."
sudo ufw --force reset
sudo ufw allow OpenSSH
if [[ $INSTALL_NGINX == "y" || $INSTALL_NGINX == "Y" ]]; then
    sudo ufw allow 'Nginx Full'
else
    sudo ufw allow 5000
fi
sudo ufw --force enable

# Create backup script
echo "Setting up backup script..."
sudo tee /etc/cron.daily/servicedesk-backup << 'EOF'
#!/bin/bash
BACKUP_DIR="/var/backups/servicedesk"
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p $BACKUP_DIR

# Database backup
sudo -u postgres pg_dump servicedesk > $BACKUP_DIR/servicedesk_$DATE.sql

# Keep only last 7 days of backups
find $BACKUP_DIR -name "servicedesk_*.sql" -mtime +7 -delete

echo "Backup completed: $DATE"
EOF

sudo chmod +x /etc/cron.daily/servicedesk-backup

# Create status check script
cat > check_status.sh << 'EOF'
#!/bin/bash
echo "=== IT Service Desk Status ==="
echo ""
echo "Application Status:"
pm2 status servicedesk

echo ""
echo "Application Logs (last 10 lines):"
pm2 logs servicedesk --lines 10 --nostream

echo ""
echo "System Resources:"
echo "Memory Usage:"
free -h
echo ""
echo "Disk Usage:"
df -h

echo ""
echo "Network Status:"
if command -v nginx &> /dev/null; then
    sudo systemctl status nginx --no-pager -l
fi

echo ""
echo "Database Status:"
sudo systemctl status postgresql --no-pager -l
EOF

chmod +x check_status.sh

# Create restart script
cat > restart_app.sh << 'EOF'
#!/bin/bash
echo "Restarting IT Service Desk application..."
pm2 restart servicedesk
pm2 logs servicedesk --lines 5 --nostream
echo "Application restarted successfully!"
EOF

chmod +x restart_app.sh

echo ""
echo "=== Deployment Complete! ==="
echo ""
echo "Application is running on:"
if [[ $INSTALL_NGINX == "y" || $INSTALL_NGINX == "Y" ]]; then
    echo "  External URL: http://$DOMAIN"
    echo "  Direct URL:  http://$DOMAIN:5000"
else
    echo "  URL: http://$DOMAIN:5000"
fi
echo ""
echo "Default login credentials:"
echo "  Admin:   john.doe / password123"
echo "  Agent:   jane.smith / password123"
echo "  Manager: skprabakaran122 / password123"
echo ""
echo "IMPORTANT: Change these passwords immediately!"
echo ""
echo "Management Commands:"
echo "  Check status: ./check_status.sh"
echo "  Restart app:  ./restart_app.sh"
echo "  View logs:    pm2 logs servicedesk"
echo "  Stop app:     pm2 stop servicedesk"
echo "  Start app:    pm2 start servicedesk"
echo ""
echo "Application logs are stored in: $APP_DIR/logs/"
echo "Database backups are stored in: /var/backups/servicedesk/"
echo ""

# Show final status
echo "Current application status:"
pm2 status servicedesk