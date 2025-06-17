#!/bin/bash

# Complete IT Service Desk Production Deployment
# Single script for Nginx + Git + PostgreSQL + PM2

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=== IT Service Desk Production Deployment ===${NC}"

# Get inputs
read -p "Git repository URL: " GIT_REPO
read -p "Domain name (or IP): " DOMAIN
read -s -p "Database password: " DB_PASSWORD
echo ""
echo "SSL Certificate Options:"
echo "1) Let's Encrypt (free, trusted, requires domain)"
echo "2) Self-signed (free, browser warning, works with IP)"
echo "3) No SSL (HTTP only)"
read -p "Choose SSL option (1/2/3): " SSL_OPTION

# Validate
if [ -z "$GIT_REPO" ] || [ -z "$DOMAIN" ] || [ -z "$DB_PASSWORD" ]; then
    echo -e "${RED}Error: All fields required${NC}"
    exit 1
fi

APP_DIR="/var/www/servicedesk"
DB_NAME="servicedesk"
DB_USER="servicedesk_user"

echo -e "${GREEN}Starting deployment to $DOMAIN...${NC}"

# System update
echo -e "${YELLOW}Installing system packages...${NC}"
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget build-essential git ufw nginx postgresql postgresql-contrib

# Install Node.js 20
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
sudo npm install -g pm2

# Setup PostgreSQL
echo -e "${YELLOW}Configuring database...${NC}"
sudo systemctl start postgresql
sudo systemctl enable postgresql

sudo -u postgres psql << EOF
CREATE DATABASE $DB_NAME;
CREATE USER $DB_USER WITH ENCRYPTED PASSWORD '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
ALTER USER $DB_USER CREATEDB;
\q
EOF

PG_VERSION=$(sudo -u postgres psql -t -c "SELECT version();" | grep -oP 'PostgreSQL \K[0-9]+')
echo "host $DB_NAME $DB_USER 127.0.0.1/32 md5" | sudo tee -a "/etc/postgresql/$PG_VERSION/main/pg_hba.conf"
sudo systemctl restart postgresql

# Clone repository
echo -e "${YELLOW}Cloning from Git...${NC}"
sudo rm -rf $APP_DIR
sudo git clone $GIT_REPO $APP_DIR
sudo chown -R www-data:www-data $APP_DIR
cd $APP_DIR

# Environment setup
sudo tee .env << EOF
NODE_ENV=production
DATABASE_URL=postgresql://$DB_USER:$DB_PASSWORD@localhost:5432/$DB_NAME
SENDGRID_API_KEY=
PORT=5000
HOST=127.0.0.1
EOF

# Build application
echo -e "${YELLOW}Installing dependencies and building...${NC}"
# Install all dependencies first (including dev dependencies for build and db operations)
sudo npm ci
# Set ownership before running operations
sudo chown -R www-data:www-data $APP_DIR
# Build the application
sudo -u www-data npm run build
# Setup database schema (needs drizzle-kit dev dependency)
sudo -u www-data npm run db:push
# Create directories
sudo mkdir -p uploads
sudo chown -R www-data:www-data $APP_DIR
# Clean install production dependencies only for runtime
sudo npm ci --omit=dev

# SSL Setup
if [ "$SSL_OPTION" = "2" ]; then
    echo -e "${YELLOW}Creating self-signed SSL certificate...${NC}"
    sudo mkdir -p /etc/nginx/ssl
    sudo openssl req -x509 -newkey rsa:4096 -keyout /etc/nginx/ssl/servicedesk.key -out /etc/nginx/ssl/servicedesk.crt -days 365 -nodes \
        -subj "/C=US/ST=State/L=City/O=Calpion/OU=IT/CN=$DOMAIN"
    sudo chmod 600 /etc/nginx/ssl/servicedesk.key
    sudo chmod 644 /etc/nginx/ssl/servicedesk.crt
    SSL_CERT="/etc/nginx/ssl/servicedesk.crt"
    SSL_KEY="/etc/nginx/ssl/servicedesk.key"
else
    SSL_CERT="/etc/ssl/certs/ssl-cert-snakeoil.pem"
    SSL_KEY="/etc/ssl/private/ssl-cert-snakeoil.key"
fi

# Nginx configuration
echo -e "${YELLOW}Configuring Nginx...${NC}"
if [ "$SSL_OPTION" = "3" ]; then
    # HTTP only configuration
    sudo tee /etc/nginx/sites-available/servicedesk << EOF
server {
    listen 80;
    server_name $DOMAIN;

    client_max_body_size 10M;
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml text/javascript;

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
    }

    location /uploads/ {
        alias $APP_DIR/uploads/;
        expires 1y;
    }
}
EOF
else
    # HTTPS configuration
    sudo tee /etc/nginx/sites-available/servicedesk << EOF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    ssl_certificate $SSL_CERT;
    ssl_certificate_key $SSL_KEY;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384;
    ssl_prefer_server_ciphers on;
    
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    client_max_body_size 10M;
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml text/javascript;

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
    }

    location /uploads/ {
        alias $APP_DIR/uploads/;
        expires 1y;
    }
}
EOF
fi

sudo ln -sf /etc/nginx/sites-available/servicedesk /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx

# Let's Encrypt SSL
if [ "$SSL_OPTION" = "1" ]; then
    echo -e "${YELLOW}Installing Let's Encrypt SSL certificate...${NC}"
    sudo apt install -y certbot python3-certbot-nginx
    sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN
fi

# PM2 setup
sudo tee $APP_DIR/ecosystem.config.cjs << EOF
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'dist/index.js',
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

# Start application
echo -e "${YELLOW}Starting application...${NC}"
cd $APP_DIR

# Create PM2 directories
sudo mkdir -p /var/www/.pm2 /var/log/pm2
sudo chown -R www-data:www-data /var/www/.pm2 /var/log/pm2

# Verify build output exists
if [ ! -f "dist/index.js" ]; then
    echo -e "${RED}Error: Build output not found at dist/index.js${NC}"
    echo "Build files present:"
    ls -la dist/ || echo "No dist directory found"
    exit 1
fi

# Initialize PM2 for www-data user
sudo -u www-data PM2_HOME=/var/www/.pm2 pm2 start ecosystem.config.cjs
sudo -u www-data PM2_HOME=/var/www/.pm2 pm2 save

# Set up PM2 startup script
sudo env PATH=$PATH:/usr/bin PM2_HOME=/var/www/.pm2 pm2 startup systemd -u www-data --hp /var/www

# Create systemd service file with correct PM2_HOME
sudo tee /etc/systemd/system/pm2-www-data.service << EOF
[Unit]
Description=PM2 process manager
Documentation=https://pm2.keymetrics.io/
After=network.target

[Service]
Type=forking
User=www-data
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin:/usr/bin
Environment=PM2_HOME=/var/www/.pm2
PIDFile=/var/www/.pm2/pm2.pid
Restart=on-failure

ExecStart=/usr/lib/node_modules/pm2/bin/pm2 resurrect
ExecReload=/usr/lib/node_modules/pm2/bin/pm2 reload all
ExecStop=/usr/lib/node_modules/pm2/bin/pm2 kill

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the PM2 service
sudo systemctl daemon-reload
sudo systemctl enable pm2-www-data
sudo systemctl start pm2-www-data

# Update script
sudo tee /usr/local/bin/update-servicedesk << 'EOF'
#!/bin/bash
cd /var/www/servicedesk

echo "Pulling latest changes from Git..."
sudo -u www-data git pull

echo "Installing all dependencies..."
sudo -u www-data npm ci

echo "Building application..."
sudo -u www-data npm run build

echo "Updating database schema..."
sudo -u www-data npm run db:push

echo "Installing production dependencies only..."
sudo -u www-data npm ci --omit=dev

echo "Restarting application..."
sudo -u www-data PM2_HOME=/var/www/.pm2 pm2 restart servicedesk

echo "Update complete!"
EOF
sudo chmod +x /usr/local/bin/update-servicedesk

# Firewall
sudo ufw --force enable
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'

echo ""
echo -e "${GREEN}=== Deployment Complete! ===${NC}"
echo ""
if [ "$SSL_OPTION" = "1" ]; then
    echo -e "Access: https://$DOMAIN (Let's Encrypt SSL)"
elif [ "$SSL_OPTION" = "2" ]; then
    echo -e "Access: https://$DOMAIN (Self-signed SSL - browser will show warning)"
else
    echo -e "Access: http://$DOMAIN (HTTP only)"
fi
echo ""
echo -e "${GREEN}Management Commands:${NC}"
echo -e "  Update app:     sudo update-servicedesk"
echo -e "  Check status:   sudo -u www-data PM2_HOME=/var/www/.pm2 pm2 status"
echo -e "  View logs:      sudo -u www-data PM2_HOME=/var/www/.pm2 pm2 logs"
echo -e "  Restart app:    sudo -u www-data PM2_HOME=/var/www/.pm2 pm2 restart servicedesk"
echo -e "  Stop app:       sudo -u www-data PM2_HOME=/var/www/.pm2 pm2 stop servicedesk"
echo ""
echo -e "${GREEN}Configuration Files:${NC}"
echo -e "  App directory:  $APP_DIR"
echo -e "  Nginx config:   /etc/nginx/sites-available/servicedesk"
echo -e "  Environment:    $APP_DIR/.env"
if [ "$SSL_OPTION" = "2" ]; then
    echo -e "  SSL cert:       /etc/nginx/ssl/servicedesk.crt"
    echo -e "  SSL key:        /etc/nginx/ssl/servicedesk.key"
fi
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo -e "1. Add your SendGrid API key to $APP_DIR/.env"
echo -e "2. Restart: sudo -u www-data pm2 restart servicedesk"
echo -e "3. Updates: sudo update-servicedesk (pulls from Git)"