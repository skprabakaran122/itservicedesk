#!/bin/bash

# Complete Ubuntu Server Deployment Script for IT Service Desk
# Run this script on your Ubuntu server as root or with sudo privileges

set -e

echo "=== IT Service Desk - Ubuntu Deployment Script ==="
echo "This script will install and configure the complete IT Service Desk system"
echo ""

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo "Running as root - proceeding with installation"
else
   echo "Please run this script with sudo privileges"
   exit 1
fi

# Update system
echo "Step 1: Updating system packages..."
apt update && apt upgrade -y

# Install Node.js 20.x
echo "Step 2: Installing Node.js 20.x..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# Install required packages
echo "Step 3: Installing nginx, postgresql, and git..."
apt install nginx postgresql postgresql-contrib git -y

# Install PM2 globally
echo "Step 4: Installing PM2 process manager..."
npm install -g pm2

# Configure PostgreSQL
echo "Step 5: Setting up PostgreSQL database..."
systemctl start postgresql
systemctl enable postgresql

# Create database and user
sudo -u postgres psql << 'EOF'
CREATE DATABASE servicedesk;
CREATE USER servicedesk WITH PASSWORD 'SecurePass123';
GRANT ALL PRIVILEGES ON DATABASE servicedesk TO servicedesk;
ALTER USER servicedesk CREATEDB;
\q
EOF

# Configure PostgreSQL for local connections
echo "Step 6: Configuring PostgreSQL authentication..."
PG_VERSION=$(sudo -u postgres psql -t -c "SELECT version();" | grep -oE '[0-9]+\.[0-9]+' | head -1)
PG_CONFIG_DIR="/etc/postgresql/$PG_VERSION/main"

# Backup original pg_hba.conf
cp $PG_CONFIG_DIR/pg_hba.conf $PG_CONFIG_DIR/pg_hba.conf.backup

# Update pg_hba.conf for local trust authentication
cat > $PG_CONFIG_DIR/pg_hba.conf << 'EOF'
# PostgreSQL Client Authentication Configuration File
local   all             servicedesk                             trust
local   all             postgres                                peer
local   all             all                                     peer
host    all             all             127.0.0.1/32            md5
host    all             all             ::1/128                 md5
local   replication     all                                     peer
host    replication     all             127.0.0.1/32            md5
host    replication     all             ::1/128                 md5
EOF

# Restart PostgreSQL
systemctl restart postgresql

# Create application directory
echo "Step 7: Setting up application directory..."
rm -rf /var/www/itservicedesk
mkdir -p /var/www/itservicedesk
cd /var/www/itservicedesk

# Clone repository
echo "Step 8: Cloning IT Service Desk repository..."
git clone https://github.com/skprabakaran122/itservicedesk.git .

# Install application dependencies
echo "Step 9: Installing application dependencies..."
npm install

# Create environment file
echo "Step 10: Creating environment configuration..."
cat > .env << 'EOF'
NODE_ENV=production
PORT=3000
DATABASE_URL=postgresql://servicedesk:SecurePass123@localhost:5432/servicedesk
SENDGRID_API_KEY=SG.placeholder
EOF

# Create logs directory
mkdir -p logs

# Set proper permissions
echo "Step 11: Setting file permissions..."
chown -R www-data:www-data /var/www/itservicedesk
chmod -R 755 /var/www/itservicedesk

# Test database connection
echo "Step 12: Testing database connection..."
sudo -u postgres psql servicedesk -c "SELECT version();" > /dev/null
echo "Database connection successful"

# Configure nginx
echo "Step 13: Configuring nginx web server..."
cat > /etc/nginx/sites-available/itservicedesk << 'EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
        proxy_read_timeout 300;
    }
}
EOF

# Enable the site
ln -sf /etc/nginx/sites-available/itservicedesk /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test nginx configuration
nginx -t

# Start nginx
systemctl restart nginx
systemctl enable nginx

# Configure firewall
echo "Step 14: Configuring firewall..."
ufw allow ssh
ufw allow 'Nginx Full'
ufw --force enable

# Start application with PM2
echo "Step 15: Starting IT Service Desk application..."
cd /var/www/itservicedesk
sudo -u www-data pm2 start ecosystem.config.cjs

# Save PM2 configuration
sudo -u www-data pm2 save

# Setup PM2 startup script
sudo -u www-data pm2 startup systemd -u www-data --hp /var/www

# Get server IP
SERVER_IP=$(hostname -I | awk '{print $1}')

# Final verification
echo "Step 16: Verifying deployment..."
sleep 5

# Check PM2 status
echo "PM2 Status:"
sudo -u www-data pm2 status

# Test health endpoint
echo ""
echo "Testing application health..."
if curl -f -s http://localhost:3000/health > /dev/null; then
    echo "✓ Application health check passed"
else
    echo "⚠ Application health check failed - checking logs..."
    sudo -u www-data pm2 logs servicedesk --lines 10
fi

# Display completion message
echo ""
echo "=== Deployment Complete ==="
echo "IT Service Desk is now running on your Ubuntu server!"
echo ""
echo "Access your application at: http://$SERVER_IP"
echo ""
echo "Login Credentials:"
echo "  Admin: test.admin / password123"
echo "  User:  test.user / password123"
echo "  Agent: john.doe / password123"
echo ""
echo "Management Commands:"
echo "  View logs: sudo -u www-data pm2 logs servicedesk"
echo "  Restart:   sudo -u www-data pm2 restart servicedesk"
echo "  Status:    sudo -u www-data pm2 status"
echo ""
echo "Application files: /var/www/itservicedesk"
echo "Database: PostgreSQL (servicedesk database)"
echo "Web server: Nginx on port 80"
echo "Application: Node.js on port 3000"
echo ""