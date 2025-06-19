#!/bin/bash

# Clean Installation Script for IT Service Desk on Ubuntu
# Removes all existing files and performs fresh installation

set -e

echo "=== IT Service Desk - Clean Installation ==="
echo "This script will remove all existing files and perform a fresh installation"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "Please run this script with sudo privileges: sudo bash clean-install-ubuntu.sh"
   exit 1
fi

# Stop and remove all PM2 processes
echo "Step 1: Cleaning up existing PM2 processes..."
pkill -f pm2 2>/dev/null || true
rm -rf /root/.pm2 2>/dev/null || true
rm -rf /home/*/.pm2 2>/dev/null || true
rm -rf /var/www/.pm2 2>/dev/null || true

# Remove existing application directory
echo "Step 2: Removing existing application files..."
rm -rf /var/www/itservicedesk
rm -rf /var/www/html
systemctl stop nginx 2>/dev/null || true

# Clean nginx configuration
echo "Step 3: Cleaning nginx configuration..."
rm -f /etc/nginx/sites-enabled/itservicedesk
rm -f /etc/nginx/sites-available/itservicedesk
rm -f /etc/nginx/sites-enabled/default

# Stop PostgreSQL and clean database
echo "Step 4: Cleaning PostgreSQL database..."
systemctl stop postgresql 2>/dev/null || true
sudo -u postgres dropdb servicedesk 2>/dev/null || true
sudo -u postgres dropuser servicedesk 2>/dev/null || true

# Start PostgreSQL
systemctl start postgresql
systemctl enable postgresql

# Create fresh database
echo "Step 5: Creating fresh database..."
sudo -u postgres psql << 'EOF'
CREATE DATABASE servicedesk;
CREATE USER servicedesk WITH PASSWORD 'SecurePass123';
GRANT ALL PRIVILEGES ON DATABASE servicedesk TO servicedesk;
ALTER USER servicedesk CREATEDB;
\q
EOF

# Configure PostgreSQL authentication
echo "Step 6: Configuring PostgreSQL authentication..."
PG_VERSION=$(sudo -u postgres psql -t -c "SHOW server_version;" | grep -oE '[0-9]+' | head -1)
PG_CONFIG_DIR="/etc/postgresql/$PG_VERSION/main"

# Backup and update pg_hba.conf
cp $PG_CONFIG_DIR/pg_hba.conf $PG_CONFIG_DIR/pg_hba.conf.backup

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

# Test database connection
echo "Step 7: Testing database connection..."
sudo -u postgres psql servicedesk -c "SELECT version();" > /dev/null
echo "✓ Database connection successful"

# Create application directory with proper structure
echo "Step 8: Creating application directory..."
mkdir -p /var/www/itservicedesk
cd /var/www/itservicedesk

# Clone fresh repository
echo "Step 9: Cloning fresh repository..."
git clone https://github.com/skprabakaran122/itservicedesk.git .

# Install dependencies
echo "Step 10: Installing dependencies..."
npm install

# Create environment configuration
echo "Step 11: Creating environment configuration..."
cat > .env << 'EOF'
NODE_ENV=production
PORT=3000
DATABASE_URL=postgresql://servicedesk:SecurePass123@localhost:5432/servicedesk
SENDGRID_API_KEY=SG.placeholder
EOF

# Create logs directory
mkdir -p logs

# Set up proper PM2 home directory
echo "Step 12: Setting up PM2 environment..."
export PM2_HOME="/home/ubuntu/.pm2"
mkdir -p $PM2_HOME
chown -R ubuntu:ubuntu $PM2_HOME

# Set proper permissions for application
echo "Step 13: Setting proper permissions..."
chown -R ubuntu:ubuntu /var/www/itservicedesk
chmod -R 755 /var/www/itservicedesk

# Start application as ubuntu user
echo "Step 14: Starting application..."
cd /var/www/itservicedesk
sudo -u ubuntu -H PM2_HOME=/home/ubuntu/.pm2 pm2 start ecosystem.config.cjs

# Save PM2 configuration
sudo -u ubuntu -H PM2_HOME=/home/ubuntu/.pm2 pm2 save

# Setup PM2 startup
sudo -u ubuntu -H PM2_HOME=/home/ubuntu/.pm2 pm2 startup systemd -u ubuntu --hp /home/ubuntu

# Configure nginx
echo "Step 15: Configuring nginx..."
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

# Enable nginx site
ln -sf /etc/nginx/sites-available/itservicedesk /etc/nginx/sites-enabled/
nginx -t
systemctl start nginx
systemctl enable nginx

# Configure firewall
echo "Step 16: Configuring firewall..."
ufw --force reset
ufw allow ssh
ufw allow 'Nginx Full'
ufw --force enable

# Get server IP
SERVER_IP=$(hostname -I | awk '{print $1}')

# Final verification
echo "Step 17: Verifying installation..."
sleep 10

# Check PM2 status
echo "PM2 Status:"
sudo -u ubuntu -H PM2_HOME=/home/ubuntu/.pm2 pm2 status

# Test application
echo ""
echo "Testing application health..."
for i in {1..5}; do
    if curl -f -s http://localhost:3000/health > /dev/null; then
        echo "✓ Application is running successfully"
        break
    else
        echo "Attempt $i: Application starting up..."
        sleep 5
    fi
done

# Display final status
echo ""
echo "=== Clean Installation Complete ==="
echo "✓ All previous files removed"
echo "✓ Fresh database created"
echo "✓ Application installed and running"
echo "✓ PM2 configured with proper permissions"
echo "✓ Nginx proxy configured"
echo "✓ Firewall configured"
echo ""
echo "🌐 Access your IT Service Desk at: http://$SERVER_IP"
echo ""
echo "📝 Login Credentials:"
echo "   Admin: test.admin / password123"
echo "   User:  test.user / password123"
echo "   Agent: john.doe / password123"
echo ""
echo "🔧 Management Commands:"
echo "   View status: sudo -u ubuntu pm2 status"
echo "   View logs:   sudo -u ubuntu pm2 logs servicedesk"
echo "   Restart:     sudo -u ubuntu pm2 restart servicedesk"
echo ""
echo "📁 Application files: /var/www/itservicedesk"
echo "🗄️  Database: PostgreSQL (servicedesk database)"
echo "🌐 Web server: Nginx on port 80"
echo "⚡ Application: Node.js on port 3000"