#!/bin/bash

# IT Service Desk Server Setup Script
# Run this directly on your Ubuntu server after uploading the project files

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_DIR="/home/ubuntu/servicedesk"
DB_NAME="servicedesk"
DB_USER="servicedesk_user"

echo -e "${BLUE}=== IT Service Desk Server Setup ===${NC}"
echo -e "${BLUE}This script will set up your server with:${NC}"
echo -e "• Node.js 20 and npm"
echo -e "• PostgreSQL database"
echo -e "• PM2 process manager"
echo -e "• SSL certificates"
echo -e "• Firewall configuration"
echo ""

# Get database password
read -s -p "Create a password for database user '$DB_USER': " DB_PASSWORD
echo ""

if [ -z "$DB_PASSWORD" ]; then
    echo -e "${RED}Error: Database password is required${NC}"
    exit 1
fi

# Get server IP for SSL certificate
SERVER_IP=$(curl -s http://checkip.amazonaws.com || hostname -I | awk '{print $1}')
echo -e "${GREEN}Detected server IP: $SERVER_IP${NC}"

echo -e "${GREEN}Starting server setup...${NC}"

# Update system
echo -e "${YELLOW}Updating system packages...${NC}"
sudo apt update && sudo apt upgrade -y

# Install essential packages
echo -e "${YELLOW}Installing essential packages...${NC}"
sudo apt install -y curl wget gnupg2 software-properties-common apt-transport-https ca-certificates \
                    build-essential git ufw openssl

# Install Node.js 20
echo -e "${YELLOW}Installing Node.js 20...${NC}"
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Verify Node.js installation
node_version=$(node --version)
npm_version=$(npm --version)
echo -e "${GREEN}Node.js installed: $node_version${NC}"
echo -e "${GREEN}npm installed: $npm_version${NC}"

# Install PM2 globally
echo -e "${YELLOW}Installing PM2...${NC}"
sudo npm install -g pm2

# Install PostgreSQL
echo -e "${YELLOW}Installing PostgreSQL...${NC}"
sudo apt install -y postgresql postgresql-contrib

# Start and enable PostgreSQL
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Create database and user
echo -e "${YELLOW}Setting up database...${NC}"
sudo -u postgres psql << PSQL
CREATE DATABASE $DB_NAME;
CREATE USER $DB_USER WITH ENCRYPTED PASSWORD '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
ALTER USER $DB_USER CREATEDB;
\q
PSQL

# Configure PostgreSQL for application access
echo -e "${YELLOW}Configuring PostgreSQL...${NC}"
PG_VERSION=$(sudo -u postgres psql -t -c "SELECT version();" | grep -oP 'PostgreSQL \K[0-9]+')
PG_CONFIG_DIR="/etc/postgresql/$PG_VERSION/main"

# Backup original config
sudo cp "$PG_CONFIG_DIR/postgresql.conf" "$PG_CONFIG_DIR/postgresql.conf.backup"
sudo cp "$PG_CONFIG_DIR/pg_hba.conf" "$PG_CONFIG_DIR/pg_hba.conf.backup"

# Configure PostgreSQL to listen on all addresses
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" "$PG_CONFIG_DIR/postgresql.conf"

# Add authentication rule for application user
echo "host    $DB_NAME    $DB_USER    127.0.0.1/32    md5" | sudo tee -a "$PG_CONFIG_DIR/pg_hba.conf"

# Restart PostgreSQL
sudo systemctl restart postgresql

# Create application directory
echo -e "${YELLOW}Creating application directory...${NC}"
mkdir -p $APP_DIR
cd $APP_DIR

# Create environment file
echo -e "${YELLOW}Creating environment configuration...${NC}"
cat > .env << ENV
NODE_ENV=production
DATABASE_URL=postgresql://$DB_USER:$DB_PASSWORD@localhost:5432/$DB_NAME
SENDGRID_API_KEY=${SENDGRID_API_KEY:-}
PORT=5000
HTTPS_PORT=5001
SSL_KEY_PATH=./ssl/key.pem
SSL_CERT_PATH=./ssl/cert.pem
ENV

echo -e "${GREEN}Environment file created at $APP_DIR/.env${NC}"
echo -e "${YELLOW}Note: Add your SENDGRID_API_KEY to .env file for email functionality${NC}"

# Install dependencies (if package.json exists)
if [ -f "package.json" ]; then
    echo -e "${YELLOW}Installing application dependencies...${NC}"
    npm ci --only=production
else
    echo -e "${YELLOW}No package.json found. Copy your project files to $APP_DIR first.${NC}"
fi

# Create SSL directory and certificates
echo -e "${YELLOW}Creating SSL certificates...${NC}"
mkdir -p ssl
openssl req -x509 -newkey rsa:4096 -keyout ssl/key.pem -out ssl/cert.pem -days 365 -nodes \
    -subj "/C=US/ST=State/L=City/O=Calpion/OU=IT/CN=$SERVER_IP"

# Set proper permissions
chmod 600 ssl/key.pem
chmod 644 ssl/cert.pem

# Create uploads directory
mkdir -p uploads
chmod 755 uploads

# Configure firewall
echo -e "${YELLOW}Configuring firewall...${NC}"
sudo ufw --force enable
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 5000/tcp
sudo ufw allow 5001/tcp

echo ""
echo -e "${GREEN}=== Server Setup Complete! ===${NC}"
echo ""
echo -e "${GREEN}What's been set up:${NC}"
echo -e "• Node.js $node_version and npm $npm_version"
echo -e "• PostgreSQL database: $DB_NAME"
echo -e "• Database user: $DB_USER"
echo -e "• SSL certificates generated"
echo -e "• Firewall configured"
echo -e "• Application directory: $APP_DIR"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. Copy your project files to $APP_DIR"
echo -e "2. Run: cd $APP_DIR && npm ci --only=production"
echo -e "3. Run: npm run build"
echo -e "4. Run: npm run db:push"
echo -e "5. Run: pm2 start ecosystem.config.cjs --env production"
echo -e "6. Run: pm2 save && pm2 startup"
echo ""
echo -e "${GREEN}Your application will be available at:${NC}"
echo -e "  HTTPS: https://$SERVER_IP:5001"
echo -e "  HTTP:  http://$SERVER_IP:5000 (redirects to HTTPS)"
echo ""
echo -e "${YELLOW}To add SendGrid email:${NC}"
echo -e "  Edit $APP_DIR/.env and add: SENDGRID_API_KEY=your_actual_key"
echo -e "  Then restart: pm2 restart calpion-service-desk"