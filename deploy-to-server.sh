#!/bin/bash

# Deployment Script for Calpion IT Service Desk with HTTPS
# This script deploys the application to a remote Ubuntu server

set -e

# Configuration
SERVER_USER="ubuntu"
SERVER_HOST=""
PPK_KEY=""
APP_NAME="calpion-service-desk"
DEPLOY_DIR="/home/ubuntu/servicedesk"
DOMAIN=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Calpion IT Service Desk - Server Deployment${NC}"
echo "================================================="

# Function to check if required tools are installed
check_dependencies() {
    echo -e "${YELLOW}Checking dependencies...${NC}"
    
    if ! command -v rsync &> /dev/null; then
        echo -e "${RED}Error: rsync is required but not installed${NC}"
        exit 1
    fi
    
    if ! command -v ssh &> /dev/null; then
        echo -e "${RED}Error: ssh is required but not installed${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Dependencies check passed${NC}"
}

# Function to convert PPK to PEM if needed
convert_ppk_to_pem() {
    local ppk_file=$1
    local pem_file="${ppk_file%.ppk}.pem"
    
    if [[ "$ppk_file" == *.ppk ]]; then
        echo -e "${YELLOW}Converting PPK to PEM format...${NC}"
        
        if command -v puttygen &> /dev/null; then
            puttygen "$ppk_file" -O private-openssh -o "$pem_file"
            chmod 600 "$pem_file"
            echo "$pem_file"
        else
            echo -e "${RED}Error: puttygen not found. Install putty-tools or provide a PEM key${NC}"
            echo "Ubuntu/Debian: sudo apt install putty-tools"
            echo "Or convert your PPK key to PEM format manually"
            exit 1
        fi
    else
        echo "$ppk_file"
    fi
}

# Function to setup server environment
setup_server() {
    local ssh_key=$1
    
    echo -e "${YELLOW}Setting up server environment...${NC}"
    
    ssh -i "$ssh_key" -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_HOST" << 'EOF'
        # Update system
        sudo apt update
        sudo apt upgrade -y
        
        # Install Node.js 20
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
        sudo apt install -y nodejs
        
        # Install PM2 globally
        sudo npm install -g pm2
        
        # Install PostgreSQL client tools
        sudo apt install -y postgresql-client
        
        # Install SSL tools
        sudo apt install -y openssl certbot nginx
        
        # Install build tools
        sudo apt install -y build-essential
        
        # Create application directory
        mkdir -p /home/ubuntu/servicedesk
        cd /home/ubuntu/servicedesk
        
        echo "✓ Server environment setup complete"
EOF
    
    echo -e "${GREEN}✓ Server environment configured${NC}"
}

# Function to deploy application files
deploy_app() {
    local ssh_key=$1
    
    echo -e "${YELLOW}Deploying application files...${NC}"
    
    # Create deployment package
    echo "Creating deployment package..."
    tar --exclude=node_modules \
        --exclude=.git \
        --exclude=ssl \
        --exclude=uploads \
        --exclude=*.log \
        -czf deployment.tar.gz .
    
    # Copy files to server
    echo "Copying files to server..."
    scp -i "$ssh_key" -o StrictHostKeyChecking=no deployment.tar.gz "$SERVER_USER@$SERVER_HOST:$DEPLOY_DIR/"
    
    # Extract and setup on server
    ssh -i "$ssh_key" -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_HOST" << EOF
        cd $DEPLOY_DIR
        
        # Backup existing deployment
        if [ -d "backup" ]; then
            rm -rf backup
        fi
        if [ -f "package.json" ]; then
            mkdir -p backup
            cp -r * backup/ 2>/dev/null || true
        fi
        
        # Extract new deployment
        tar -xzf deployment.tar.gz
        rm deployment.tar.gz
        
        # Install dependencies
        npm install --production
        
        # Create necessary directories
        mkdir -p uploads ssl logs
        
        echo "✓ Application files deployed"
EOF
    
    # Clean up local deployment package
    rm deployment.tar.gz
    
    echo -e "${GREEN}✓ Application deployed${NC}"
}

# Function to setup SSL certificates
setup_ssl() {
    local ssh_key=$1
    local domain=$2
    
    if [ -z "$domain" ]; then
        echo -e "${YELLOW}Setting up self-signed SSL certificate...${NC}"
        
        ssh -i "$ssh_key" -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_HOST" << EOF
            cd $DEPLOY_DIR
            
            # Generate self-signed certificate
            openssl req -x509 -newkey rsa:4096 -keyout ssl/key.pem -out ssl/cert.pem -days 365 -nodes \
                -subj "/C=US/ST=State/L=City/O=Calpion/OU=IT/CN=\$(curl -s http://checkip.amazonaws.com)"
            
            chmod 600 ssl/key.pem
            chmod 644 ssl/cert.pem
            
            echo "✓ Self-signed SSL certificate generated"
EOF
    else
        echo -e "${YELLOW}Setting up Let's Encrypt SSL certificate for $domain...${NC}"
        
        ssh -i "$ssh_key" -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_HOST" << EOF
            # Stop any services using port 80
            sudo fuser -k 80/tcp || true
            
            # Generate Let's Encrypt certificate
            sudo certbot certonly --standalone --agree-tos --no-eff-email -d $domain
            
            # Copy certificates to application directory
            sudo cp /etc/letsencrypt/live/$domain/fullchain.pem $DEPLOY_DIR/ssl/cert.pem
            sudo cp /etc/letsencrypt/live/$domain/privkey.pem $DEPLOY_DIR/ssl/key.pem
            sudo chown ubuntu:ubuntu $DEPLOY_DIR/ssl/cert.pem $DEPLOY_DIR/ssl/key.pem
            
            # Setup auto-renewal
            (sudo crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet && cp /etc/letsencrypt/live/$domain/fullchain.pem $DEPLOY_DIR/ssl/cert.pem && cp /etc/letsencrypt/live/$domain/privkey.pem $DEPLOY_DIR/ssl/key.pem && chown ubuntu:ubuntu $DEPLOY_DIR/ssl/cert.pem $DEPLOY_DIR/ssl/key.pem && pm2 restart $APP_NAME") | sudo crontab -
            
            echo "✓ Let's Encrypt SSL certificate configured"
EOF
    fi
    
    echo -e "${GREEN}✓ SSL certificates configured${NC}"
}

# Function to configure environment
setup_environment() {
    local ssh_key=$1
    
    echo -e "${YELLOW}Configuring environment variables...${NC}"
    
    ssh -i "$ssh_key" -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_HOST" << 'EOF'
        cd /home/ubuntu/servicedesk
        
        # Create production environment file
        cat > .env << 'ENVEOF'
NODE_ENV=production
PGDATABASE=neondb
PGHOST=ep-still-snow-a65c90fl.us-west-2.aws.neon.tech
PGUSER=neondb_owner
PGPASSWORD=npg_CHFj1dqMYB6V
PGPORT=5432
DATABASE_URL="postgresql://neondb_owner:npg_CHFj1dqMYB6V@ep-still-snow-a65c90fl.us-west-2.aws.neon.tech/neondb?sslmode=require"
SENDGRID_API_KEY=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
ENVEOF
        
        chmod 600 .env
        
        echo "✓ Environment configured"
EOF
    
    echo -e "${GREEN}✓ Environment variables configured${NC}"
}

# Function to configure firewall
setup_firewall() {
    local ssh_key=$1
    
    echo -e "${YELLOW}Configuring firewall...${NC}"
    
    ssh -i "$ssh_key" -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_HOST" << 'EOF'
        # Enable UFW
        sudo ufw --force enable
        
        # Allow SSH
        sudo ufw allow ssh
        
        # Allow HTTP and HTTPS
        sudo ufw allow 80/tcp
        sudo ufw allow 443/tcp
        
        # Allow application ports
        sudo ufw allow 5000/tcp
        sudo ufw allow 5001/tcp
        
        # Show status
        sudo ufw status
        
        echo "✓ Firewall configured"
EOF
    
    echo -e "${GREEN}✓ Firewall configured${NC}"
}

# Function to start application
start_application() {
    local ssh_key=$1
    
    echo -e "${YELLOW}Starting application with PM2...${NC}"
    
    ssh -i "$ssh_key" -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_HOST" << EOF
        cd $DEPLOY_DIR
        
        # Push database schema
        npm run db:push
        
        # Stop existing PM2 processes
        pm2 stop $APP_NAME || true
        pm2 delete $APP_NAME || true
        
        # Start application with PM2
        pm2 start ecosystem.config.cjs --name $APP_NAME
        
        # Save PM2 configuration
        pm2 save
        
        # Setup PM2 startup
        pm2 startup | grep 'sudo env' | bash || true
        
        # Show status
        pm2 status
        pm2 logs $APP_NAME --lines 10
        
        echo "✓ Application started"
EOF
    
    echo -e "${GREEN}✓ Application started with PM2${NC}"
}

# Main deployment function
deploy() {
    echo "Please provide the following information:"
    
    if [ -z "$SERVER_HOST" ]; then
        read -p "Server IP address or hostname: " SERVER_HOST
    fi
    
    if [ -z "$PPK_KEY" ]; then
        read -p "Path to PPK/PEM key file: " PPK_KEY
    fi
    
    read -p "Domain name (optional, press Enter for self-signed cert): " DOMAIN
    
    # Validate inputs
    if [ -z "$SERVER_HOST" ] || [ -z "$PPK_KEY" ]; then
        echo -e "${RED}Error: Server host and key file are required${NC}"
        exit 1
    fi
    
    if [ ! -f "$PPK_KEY" ]; then
        echo -e "${RED}Error: Key file not found: $PPK_KEY${NC}"
        exit 1
    fi
    
    # Convert PPK to PEM if needed
    SSH_KEY=$(convert_ppk_to_pem "$PPK_KEY")
    
    # Test SSH connection
    echo -e "${YELLOW}Testing SSH connection...${NC}"
    if ! ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER_USER@$SERVER_HOST" "echo 'SSH connection successful'"; then
        echo -e "${RED}Error: Cannot connect to server${NC}"
        exit 1
    fi
    
    # Run deployment steps
    check_dependencies
    setup_server "$SSH_KEY"
    deploy_app "$SSH_KEY"
    setup_environment "$SSH_KEY"
    setup_ssl "$SSH_KEY" "$DOMAIN"
    setup_firewall "$SSH_KEY"
    start_application "$SSH_KEY"
    
    echo ""
    echo -e "${GREEN}🎉 Deployment Complete!${NC}"
    echo "================================"
    echo -e "Your application is now running at:"
    echo -e "  • HTTPS: ${BLUE}https://$SERVER_HOST:5001${NC}"
    echo -e "  • HTTP:  ${BLUE}http://$SERVER_HOST:5000${NC} (redirects to HTTPS)"
    
    if [ ! -z "$DOMAIN" ]; then
        echo -e "  • Domain: ${BLUE}https://$DOMAIN${NC}"
    fi
    
    echo ""
    echo "Useful commands:"
    echo "  • Check logs: ssh -i $SSH_KEY $SERVER_USER@$SERVER_HOST 'pm2 logs $APP_NAME'"
    echo "  • Restart app: ssh -i $SSH_KEY $SERVER_USER@$SERVER_HOST 'pm2 restart $APP_NAME'"
    echo "  • Check status: ssh -i $SSH_KEY $SERVER_USER@$SERVER_HOST 'pm2 status'"
}

# Run deployment
deploy