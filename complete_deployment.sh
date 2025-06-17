#!/bin/bash

# Complete IT Service Desk Deployment Script for Fresh Ubuntu Server
# This script sets up everything needed for production deployment

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SERVER_USER="ubuntu"
APP_DIR="/home/ubuntu/servicedesk"
DB_NAME="servicedesk"
DB_USER="servicedesk_user"
NODE_VERSION="20"

echo -e "${BLUE}=== IT Service Desk Complete Deployment Script ===${NC}"
echo -e "${BLUE}This script will set up your production server with:${NC}"
echo -e "• Node.js 20 and npm"
echo -e "• PostgreSQL database"
echo -e "• PM2 process manager"
echo -e "• SSL certificates"
echo -e "• Firewall configuration"
echo -e "• Application deployment"
echo ""

# Get server details
read -p "Enter your server IP address: " SERVER_IP
read -p "Enter your SSH key path (e.g., ./my-key.pem): " SSH_KEY
read -s -p "Create a password for database user: " DB_PASSWORD
echo ""

# Validate inputs
if [ -z "$SERVER_IP" ] || [ -z "$SSH_KEY" ] || [ -z "$DB_PASSWORD" ]; then
    echo -e "${RED}Error: All fields are required${NC}"
    exit 1
fi

if [ ! -f "$SSH_KEY" ]; then
    echo -e "${RED}Error: SSH key file not found at $SSH_KEY${NC}"
    exit 1
fi

echo -e "${GREEN}Starting deployment to $SERVER_IP...${NC}"

# Create deployment package
echo -e "${YELLOW}Creating deployment package...${NC}"
tar --exclude=node_modules --exclude=.git --exclude=ssl --exclude=uploads --exclude=attached_assets \
    -czf deployment-package.tar.gz \
    server/ client/ shared/ \
    package.json package-lock.json \
    tsconfig.json vite.config.ts tailwind.config.ts postcss.config.js \
    drizzle.config.ts ecosystem.config.cjs \
    .env

echo -e "${GREEN}Deployment package created${NC}"

# Copy files to server
echo -e "${YELLOW}Copying files to server...${NC}"
scp -i "$SSH_KEY" deployment-package.tar.gz "$SERVER_USER@$SERVER_IP:/home/ubuntu/"
scp -i "$SSH_KEY" "$0" "$SERVER_USER@$SERVER_IP:/home/ubuntu/setup.sh"

# Run setup on server
echo -e "${YELLOW}Running setup on server...${NC}"
ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_IP" << EOF
#!/bin/bash
set -e

echo "=== Starting server setup ==="

# Update system
echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install essential packages
echo "Installing essential packages..."
sudo apt install -y curl wget gnupg2 software-properties-common apt-transport-https ca-certificates \
                    build-essential git ufw nginx-core openssl

# Install Node.js 20
echo "Installing Node.js 20..."
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Verify Node.js installation
node_version=\$(node --version)
npm_version=\$(npm --version)
echo "Node.js installed: \$node_version"
echo "npm installed: \$npm_version"

# Install PM2 globally
echo "Installing PM2..."
sudo npm install -g pm2

# Install PostgreSQL
echo "Installing PostgreSQL..."
sudo apt install -y postgresql postgresql-contrib

# Start and enable PostgreSQL
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Create database and user
echo "Setting up database..."
sudo -u postgres psql << PSQL
CREATE DATABASE $DB_NAME;
CREATE USER $DB_USER WITH ENCRYPTED PASSWORD '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
ALTER USER $DB_USER CREATEDB;
\\q
PSQL

# Configure PostgreSQL for application access
echo "Configuring PostgreSQL..."
PG_VERSION=\$(sudo -u postgres psql -t -c "SELECT version();" | grep -oP 'PostgreSQL \\K[0-9]+')
PG_CONFIG_DIR="/etc/postgresql/\$PG_VERSION/main"

# Backup original config
sudo cp "\$PG_CONFIG_DIR/postgresql.conf" "\$PG_CONFIG_DIR/postgresql.conf.backup"
sudo cp "\$PG_CONFIG_DIR/pg_hba.conf" "\$PG_CONFIG_DIR/pg_hba.conf.backup"

# Configure PostgreSQL to listen on all addresses
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" "\$PG_CONFIG_DIR/postgresql.conf"

# Add authentication rule for application user
echo "host    $DB_NAME    $DB_USER    127.0.0.1/32    md5" | sudo tee -a "\$PG_CONFIG_DIR/pg_hba.conf"

# Restart PostgreSQL
sudo systemctl restart postgresql

# Create application directory
echo "Creating application directory..."
mkdir -p $APP_DIR
cd $APP_DIR

# Extract application files
echo "Extracting application files..."
tar -xzf /home/ubuntu/deployment-package.tar.gz

# Create environment file
echo "Creating environment configuration..."
cat > .env << ENV
NODE_ENV=production
DATABASE_URL=postgresql://$DB_USER:$DB_PASSWORD@localhost:5432/$DB_NAME
SENDGRID_API_KEY=\${SENDGRID_API_KEY:-}
PORT=5000
HTTPS_PORT=5001
SSL_KEY_PATH=./ssl/key.pem
SSL_CERT_PATH=./ssl/cert.pem
ENV

# Install dependencies
echo "Installing application dependencies..."
npm ci --only=production

# Create SSL directory and certificates
echo "Creating SSL certificates..."
mkdir -p ssl
openssl req -x509 -newkey rsa:4096 -keyout ssl/key.pem -out ssl/cert.pem -days 365 -nodes \\
    -subj "/C=US/ST=State/L=City/O=Calpion/OU=IT/CN=$SERVER_IP"

# Set proper permissions
chmod 600 ssl/key.pem
chmod 644 ssl/cert.pem

# Build application
echo "Building application..."
npm run build

# Run database migrations
echo "Running database migrations..."
npm run db:push

# Create uploads directory
mkdir -p uploads
chmod 755 uploads

# Configure firewall
echo "Configuring firewall..."
sudo ufw --force enable
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 5000/tcp
sudo ufw allow 5001/tcp

# Start application with PM2
echo "Starting application..."
pm2 start ecosystem.config.cjs --env production
pm2 save
pm2 startup

# Clean up
rm -f /home/ubuntu/deployment-package.tar.gz
rm -f /home/ubuntu/setup.sh

echo ""
echo "=== Deployment Complete ==="
echo "Application is running on:"
echo "  HTTPS: https://$SERVER_IP:5001"
echo "  HTTP:  http://$SERVER_IP:5000 (redirects to HTTPS)"
echo ""
echo "Database: PostgreSQL"
echo "  Host: localhost"
echo "  Database: $DB_NAME"
echo "  User: $DB_USER"
echo ""
echo "Process Manager: PM2"
echo "  Status: pm2 status"
echo "  Logs:   pm2 logs"
echo "  Restart: pm2 restart calpion-service-desk"
echo ""
echo "SSL Certificates: Self-signed (valid for 1 year)"
echo "  Location: $APP_DIR/ssl/"
echo ""

EOF

echo -e "${GREEN}=== Deployment Complete! ===${NC}"
echo -e "${GREEN}Your IT Service Desk is now running at:${NC}"
echo -e "  HTTPS: https://$SERVER_IP:5001"
echo -e "  HTTP:  http://$SERVER_IP:5000"
echo ""
echo -e "${YELLOW}Important Notes:${NC}"
echo -e "• SSL certificates are self-signed (browsers will show security warning)"
echo -e "• To add SendGrid email, SSH to server and update .env with SENDGRID_API_KEY"
echo -e "• Monitor with: ssh -i $SSH_KEY $SERVER_USER@$SERVER_IP 'pm2 status'"
echo -e "• View logs: ssh -i $SSH_KEY $SERVER_USER@$SERVER_IP 'pm2 logs'"
echo ""
echo -e "${GREEN}Deployment successful!${NC}"

# Clean up local files
rm -f deployment-package.tar.gz