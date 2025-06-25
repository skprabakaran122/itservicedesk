#!/bin/bash

# Ubuntu AWS Production Deployment Script
# For IT Service Desk with RDS Database

set -e

echo "🚀 Starting Ubuntu AWS Production Deployment..."

# Configuration
APP_NAME="itservicedesk"
APP_USER="ubuntu"
APP_DIR="/opt/$APP_NAME"
SERVICE_NAME="$APP_NAME"
NGINX_AVAILABLE="/etc/nginx/sites-available/$APP_NAME"
NGINX_ENABLED="/etc/nginx/sites-enabled/$APP_NAME"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   error "This script should not be run as root. Run as ubuntu user with sudo privileges."
fi

# Update system packages
log "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install required packages
log "Installing required packages..."
sudo apt install -y curl wget gnupg2 software-properties-common apt-transport-https ca-certificates lsb-release

# Install Node.js 20
log "Installing Node.js 20..."
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Verify Node.js installation
node_version=$(node --version)
npm_version=$(npm --version)
log "Node.js version: $node_version"
log "NPM version: $npm_version"

# Install PM2 globally
log "Installing PM2 process manager..."
sudo npm install -g pm2

# Install Nginx
log "Installing Nginx..."
sudo apt install -y nginx

# Install PostgreSQL client (for connecting to RDS)
log "Installing PostgreSQL client..."
sudo apt install -y postgresql-client

# Create application directory
log "Creating application directory..."
sudo mkdir -p $APP_DIR
sudo chown $APP_USER:$APP_USER $APP_DIR

# Clone or copy application code
log "Setting up application code..."
cd $APP_DIR

# If this script is run from the project directory, copy files
if [ -f "package.json" ]; then
    log "Copying application files..."
    sudo cp -r . $APP_DIR/
    sudo chown -R $APP_USER:$APP_USER $APP_DIR
else
    error "Please run this script from your project directory or modify to clone from Git"
fi

# Install dependencies
log "Installing Node.js dependencies..."
npm ci --production

# Install TypeScript execution globally
log "Installing tsx for TypeScript execution..."
sudo npm install -g tsx

# Create uploads directory
log "Creating uploads directory..."
mkdir -p $APP_DIR/uploads
mkdir -p $APP_DIR/logs
chmod 755 $APP_DIR/uploads
chmod 755 $APP_DIR/logs

# Create environment file
log "Creating production environment file..."
cat > $APP_DIR/.env << EOF
NODE_ENV=production
PORT=5000
HOST=0.0.0.0

# RDS Database Configuration
# UPDATE THESE VALUES WITH YOUR RDS DETAILS
DATABASE_URL=postgresql://username:password@your-rds-endpoint.region.rds.amazonaws.com:5432/itservicedesk?sslmode=require
DB_HOST=your-rds-endpoint.region.rds.amazonaws.com
DB_NAME=itservicedesk
DB_USER=your_db_username
DB_PASSWORD=your_db_password
DB_PORT=5432
DB_SSL_MODE=require

# File Storage
UPLOAD_DIR=$APP_DIR/uploads

# Email Configuration (Optional)
SENDGRID_API_KEY=your_sendgrid_api_key
EMAIL_FROM=no-reply@yourdomain.com

# Session Security
SESSION_SECRET=$(openssl rand -base64 32)
EOF

warn "Please edit $APP_DIR/.env with your actual RDS credentials!"

# Create PM2 ecosystem file
log "Creating PM2 configuration..."
cat > $APP_DIR/ecosystem.config.cjs << 'EOF'
module.exports = {
  apps: [{
    name: 'itservicedesk',
    script: 'tsx',
    args: 'server/index.ts',
    cwd: '/opt/itservicedesk',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production',
      PORT: 5000
    },
    error_file: '/opt/itservicedesk/logs/err.log',
    out_file: '/opt/itservicedesk/logs/out.log',
    log_file: '/opt/itservicedesk/logs/combined.log',
    time: true
  }]
};
EOF

# Create systemd service for PM2
log "Creating systemd service..."
sudo tee /etc/systemd/system/$SERVICE_NAME.service > /dev/null << EOF
[Unit]
Description=IT Service Desk Application
After=network.target

[Service]
Type=forking
User=$APP_USER
WorkingDirectory=$APP_DIR
Environment=PATH=/usr/bin:/usr/local/bin
Environment=PM2_HOME=/home/$APP_USER/.pm2
ExecStart=/usr/bin/pm2 start $APP_DIR/ecosystem.config.cjs --env production
ExecStop=/usr/bin/pm2 stop $APP_DIR/ecosystem.config.cjs
ExecReload=/usr/bin/pm2 restart $APP_DIR/ecosystem.config.cjs
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Configure Nginx
log "Configuring Nginx..."
sudo tee $NGINX_AVAILABLE > /dev/null << 'EOF'
server {
    listen 80;
    server_name _;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    # File upload size
    client_max_body_size 10M;

    # Application proxy
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }

    # Health check endpoint
    location /health {
        proxy_pass http://127.0.0.1:5000/health;
        access_log off;
    }

    # Static files (if served by nginx)
    location /uploads {
        alias /opt/itservicedesk/uploads;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

# Enable Nginx site
log "Enabling Nginx site..."
sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -sf $NGINX_AVAILABLE $NGINX_ENABLED

# Test Nginx configuration
log "Testing Nginx configuration..."
sudo nginx -t

# Configure firewall
log "Configuring UFW firewall..."
sudo ufw --force enable
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'
sudo ufw allow 5000  # Application port (optional, remove in production)

# Reload systemd
log "Reloading systemd..."
sudo systemctl daemon-reload

# Enable and start services
log "Enabling and starting services..."
sudo systemctl enable nginx
sudo systemctl enable $SERVICE_NAME

# Start Nginx
sudo systemctl restart nginx

# Build frontend if needed
if [ -f "vite.config.ts" ]; then
    log "Building frontend..."
    npm run build
fi

# Run database migrations
log "Running database migrations..."
if [ -f "migrations/run_migrations.cjs" ]; then
    node migrations/run_migrations.cjs || warn "Migration failed - please run manually after configuring RDS"
fi

# Start the application
log "Starting application with PM2..."
cd $APP_DIR
pm2 start ecosystem.config.cjs --env production
pm2 save
pm2 startup systemd -u $APP_USER --hp /home/$APP_USER

# Start systemd service
sudo systemctl start $SERVICE_NAME

# Display status
log "Checking service status..."
sudo systemctl status nginx --no-pager
sudo systemctl status $SERVICE_NAME --no-pager
pm2 status

# Show final information
echo ""
log "✅ Deployment completed successfully!"
echo ""
echo "📋 Next Steps:"
echo "1. Edit /opt/itservicedesk/.env with your RDS credentials"
echo "2. Run: sudo systemctl restart itservicedesk"
echo "3. Run migrations: cd /opt/itservicedesk && node migrations/run_migrations.cjs"
echo "4. Configure SSL certificate for production"
echo ""
echo "🌐 Application URLs:"
echo "  - HTTP: http://$(curl -s ifconfig.me)"
echo "  - Local: http://localhost"
echo "  - Health: http://localhost/health"
echo ""
echo "📊 Management Commands:"
echo "  - View logs: pm2 logs itservicedesk"
echo "  - Restart app: sudo systemctl restart itservicedesk"
echo "  - Check status: sudo systemctl status itservicedesk"
echo "  - Nginx reload: sudo systemctl reload nginx"
echo ""
warn "Don't forget to configure your RDS database connection!"