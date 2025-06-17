#!/bin/bash

# Simple deployment script to run directly on your Ubuntu server
# This sets up everything and deploys the application

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== IT Service Desk Deployment ===${NC}"

# Get database password
read -s -p "Create a database password: " DB_PASSWORD
echo ""

# Get server IP
SERVER_IP=$(curl -s http://checkip.amazonaws.com 2>/dev/null || hostname -I | awk '{print $1}')
echo "Using server IP: $SERVER_IP"

APP_DIR="/home/ubuntu/servicedesk"
DB_NAME="servicedesk"
DB_USER="servicedesk_user"

# Update system and install packages
echo -e "${YELLOW}Installing system packages...${NC}"
sudo apt update
sudo apt install -y curl wget build-essential git ufw openssl postgresql postgresql-contrib

# Install Node.js 20
echo -e "${YELLOW}Installing Node.js 20...${NC}"
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Install PM2
sudo npm install -g pm2

# Setup PostgreSQL
echo -e "${YELLOW}Setting up database...${NC}"
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

# Create application directory
mkdir -p $APP_DIR
cd $APP_DIR

# Create environment file
cat > .env << EOF
NODE_ENV=production
DATABASE_URL=postgresql://$DB_USER:$DB_PASSWORD@localhost:5432/$DB_NAME
SENDGRID_API_KEY=
PORT=5000
HTTPS_PORT=5001
SSL_KEY_PATH=./ssl/key.pem
SSL_CERT_PATH=./ssl/cert.pem
EOF

# Create SSL certificates
mkdir -p ssl uploads
openssl req -x509 -newkey rsa:4096 -keyout ssl/key.pem -out ssl/cert.pem -days 365 -nodes \
    -subj "/C=US/ST=State/L=City/O=Calpion/OU=IT/CN=$SERVER_IP"
chmod 600 ssl/key.pem
chmod 644 ssl/cert.pem
chmod 755 uploads

# Configure firewall
sudo ufw --force enable
sudo ufw allow ssh
sudo ufw allow 5000/tcp
sudo ufw allow 5001/tcp

echo -e "${GREEN}Server setup complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Copy your project files to $APP_DIR"
echo "2. Run: npm ci --only=production"
echo "3. Run: npm run build"
echo "4. Run: npm run db:push"
echo "5. Run: pm2 start ecosystem.config.cjs"
echo ""
echo "Application will be available at:"
echo "  HTTPS: https://$SERVER_IP:5001"
echo "  HTTP:  http://$SERVER_IP:5000"