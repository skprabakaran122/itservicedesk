#!/bin/bash

# Production deployment script with Nginx and Git
# Run this directly on your Ubuntu server

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== IT Service Desk Production Deployment ===${NC}"
echo -e "${BLUE}This script sets up:${NC}"
echo -e "• Nginx reverse proxy with SSL"
echo -e "• Git repository for easy updates"
echo -e "• PostgreSQL database"
echo -e "• PM2 process manager"
echo -e "• Automatic HTTPS with Let's Encrypt (optional)"
echo ""

# Get configuration
read -p "Enter your Git repository URL: " GIT_REPO
read -p "Enter your domain name (or server IP): " DOMAIN
read -s -p "Create a database password: " DB_PASSWORD
echo ""
read -p "Install Let's Encrypt SSL? (y/n): " INSTALL_SSL

if [ -z "$GIT_REPO" ] || [ -z "$DOMAIN" ] || [ -z "$DB_PASSWORD" ]; then
    echo "Error: All fields are required"
    exit 1
fi

APP_DIR="/var/www/servicedesk"
DB_NAME="servicedesk"
DB_USER="servicedesk_user"

echo -e "${GREEN}Starting production deployment...${NC}"

# Update system
echo -e "${YELLOW}Updating system packages...${NC}"
sudo apt update && sudo apt upgrade -y

# Install essential packages
echo -e "${YELLOW}Installing system packages...${NC}"
sudo apt install -y curl wget build-essential git ufw nginx postgresql postgresql-contrib certbot python3-certbot-nginx

# Install Node.js 20
echo -e "${YELLOW}Installing Node.js 20...${NC}"
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Install PM2
sudo npm install -g pm2

# Setup PostgreSQL
echo -e "${YELLOW}Setting up PostgreSQL database...${NC}"
sudo systemctl start postgresql
sudo systemctl enable postgresql

sudo -u postgres psql << EOF
CREATE DATABASE $DB_NAME;
CREATE USER $DB_USER WITH ENCRYPTED PASSWORD '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
ALTER USER $DB_USER CREATEDB;
\q
EOF

# Configure PostgreSQL
PG_VERSION=$(sudo -u postgres psql -t -c "SELECT version();" | grep -oP 'PostgreSQL \K[0-9]+')
echo "host    $DB_NAME    $DB_USER    127.0.0.1/32    md5" | sudo tee -a "/etc/postgresql/$PG_VERSION/main/pg_hba.conf"
sudo systemctl restart postgresql

# Clone repository
echo -e "${YELLOW}Cloning application from Git...${NC}"
sudo rm -rf $APP_DIR
sudo git clone $GIT_REPO $APP_DIR
sudo chown -R www-data:www-data $APP_DIR
cd $APP_DIR

# Create environment file
echo -e "${YELLOW}Creating environment configuration...${NC}"
sudo tee .env << EOF
NODE_ENV=production
DATABASE_URL=postgresql://$DB_USER:$DB_PASSWORD@localhost:5432/$DB_NAME
SENDGRID_API_KEY=
PORT=5000
HOST=127.0.0.1
EOF

# Install dependencies and build
echo -e "${YELLOW}Installing dependencies and building...${NC}"
sudo npm ci --only=production
sudo npm run build

# Create directories
sudo mkdir -p uploads ssl
sudo chmod 755 uploads
sudo chown -R www-data:www-data $APP_DIR

# Setup database
echo -e "${YELLOW}Setting up database schema...${NC}"
sudo -u www-data npm run db:push

# Configure Nginx
echo -e "${YELLOW}Configuring Nginx...${NC}"
sudo tee /etc/nginx/sites-available/servicedesk << EOF
server {
    listen 80;
    server_name $DOMAIN;

    # Redirect HTTP to HTTPS
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    # SSL configuration (will be updated by certbot if used)
    ssl_certificate /etc/ssl/certs/ssl-cert-snakeoil.pem;
    ssl_certificate_key /etc/ssl/private/ssl-cert-snakeoil.key;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Gzip compression
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    # File upload limit
    client_max_body_size 10M;

    # Proxy to Node.js application
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_read_timeout 86400;
    }

    # Static file handling
    location /uploads/ {
        alias $APP_DIR/uploads/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

# Enable site
sudo ln -sf /etc/nginx/sites-available/servicedesk /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx

# Install Let's Encrypt SSL
if [ "$INSTALL_SSL" = "y" ] || [ "$INSTALL_SSL" = "Y" ]; then
    echo -e "${YELLOW}Installing Let's Encrypt SSL certificate...${NC}"
    sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN
fi

# Create PM2 ecosystem file
sudo tee $APP_DIR/ecosystem.config.cjs << EOF
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'server/index.js',
    cwd: '$APP_DIR',
    instances: 'max',
    exec_mode: 'cluster',
    env: {
      NODE_ENV: 'production',
      PORT: 5000,
      HOST: '127.0.0.1'
    },
    error_file: '/var/log/pm2/servicedesk-error.log',
    out_file: '/var/log/pm2/servicedesk-out.log',
    log_file: '/var/log/pm2/servicedesk.log',
    time: true
  }]
};
EOF

# Create PM2 log directory
sudo mkdir -p /var/log/pm2
sudo chown -R www-data:www-data /var/log/pm2

# Start application with PM2
echo -e "${YELLOW}Starting application with PM2...${NC}"
cd $APP_DIR
sudo -u www-data pm2 start ecosystem.config.cjs
sudo -u www-data pm2 save
sudo env PATH=$PATH:/usr/bin pm2 startup -u www-data --hp /var/www

# Configure firewall
echo -e "${YELLOW}Configuring firewall...${NC}"
sudo ufw --force enable
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'

# Create update script
sudo tee /usr/local/bin/update-servicedesk << 'EOF'
#!/bin/bash
set -e

APP_DIR="/var/www/servicedesk"
cd $APP_DIR

echo "Pulling latest changes from Git..."
sudo -u www-data git pull origin main

echo "Installing dependencies..."
sudo -u www-data npm ci --only=production

echo "Building application..."
sudo -u www-data npm run build

echo "Updating database..."
sudo -u www-data npm run db:push

echo "Restarting application..."
sudo -u www-data pm2 restart servicedesk

echo "Update complete!"
EOF

sudo chmod +x /usr/local/bin/update-servicedesk

echo ""
echo -e "${GREEN}=== Deployment Complete! ===${NC}"
echo ""
echo -e "${GREEN}Your IT Service Desk is now running at:${NC}"
if [ "$INSTALL_SSL" = "y" ] || [ "$INSTALL_SSL" = "Y" ]; then
    echo -e "  https://$DOMAIN"
else
    echo -e "  https://$DOMAIN (with self-signed certificate)"
    echo -e "  http://$DOMAIN (redirects to HTTPS)"
fi
echo ""
echo -e "${GREEN}Management Commands:${NC}"
echo -e "  Update app:     sudo update-servicedesk"
echo -e "  Check status:   sudo -u www-data pm2 status"
echo -e "  View logs:      sudo -u www-data pm2 logs"
echo -e "  Restart:        sudo -u www-data pm2 restart servicedesk"
echo ""
echo -e "${GREEN}Configuration:${NC}"
echo -e "  App directory:  $APP_DIR"
echo -e "  Nginx config:   /etc/nginx/sites-available/servicedesk"
echo -e "  Environment:    $APP_DIR/.env"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo -e "1. Add your SendGrid API key to $APP_DIR/.env"
echo -e "2. Restart: sudo -u www-data pm2 restart servicedesk"
echo -e "3. Your app will automatically update from Git using: sudo update-servicedesk"