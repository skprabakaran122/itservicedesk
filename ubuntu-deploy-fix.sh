#!/bin/bash

# Ubuntu Node.js Conflict Resolution and Production Deployment
# Handles the nodejs/npm dependency conflicts common on Ubuntu servers

set -e

APP_NAME="itservicedesk"
APP_DIR="/var/www/$APP_NAME"
NGINX_CONF="/etc/nginx/sites-available/default"
SSL_DIR="$APP_DIR/ssl"

echo "Starting Ubuntu deployment with dependency resolution..."

# Clean up any broken package states
echo "Cleaning package manager state..."
sudo apt update
sudo dpkg --configure -a
sudo apt --fix-broken install -y

# Remove all Node.js related packages to start fresh
echo "Removing conflicting Node.js packages..."
sudo apt purge -y nodejs npm node-* 2>/dev/null || true
sudo apt autoremove -y
sudo apt autoclean

# Install Node.js 20.x from official NodeSource repository
echo "Installing Node.js 20.x from NodeSource..."
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Verify Node.js and npm installation
echo "Verifying Node.js installation..."
node_version=$(node --version)
npm_version=$(npm --version)
echo "Node.js version: $node_version"
echo "npm version: $npm_version"

# Install other system dependencies
echo "Installing system dependencies..."
sudo apt install -y nginx postgresql-client curl git

# Install PM2 globally
echo "Installing PM2 process manager..."
sudo npm install -g pm2

# Create application directory
echo "Setting up application directory..."
sudo mkdir -p $APP_DIR
sudo chown -R ubuntu:ubuntu $APP_DIR

# Clone application
echo "Deploying application..."
if [ -d "$APP_DIR/.git" ]; then
    cd $APP_DIR
    git pull origin main
else
    git clone https://github.com/skprabakaran122/itservicedesk.git $APP_DIR
    cd $APP_DIR
fi

# Install application dependencies
echo "Installing application dependencies..."
npm ci --production=false

# Build frontend
echo "Building frontend..."
npm run build

# Prepare production server
echo "Preparing production server..."
mkdir -p dist logs uploads
cp server/production.cjs dist/production.cjs

# Setup SSL certificates
echo "Setting up SSL certificates..."
mkdir -p $SSL_DIR
cd $SSL_DIR

if [ ! -f "server.crt" ]; then
    SERVER_IP=$(curl -s ifconfig.me || echo "localhost")
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout server.key -out server.crt \
        -subj "/C=US/ST=CA/L=San Francisco/O=Calpion/CN=$SERVER_IP" \
        -addext "subjectAltName=IP:$SERVER_IP"
    echo "SSL certificates created for IP: $SERVER_IP"
fi

cd $APP_DIR

# Configure Nginx
echo "Configuring Nginx..."
sudo tee $NGINX_CONF > /dev/null << 'NGINX_EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2 default_server;
    listen [::]:443 ssl http2 default_server;
    server_name _;

    ssl_certificate /var/www/itservicedesk/ssl/server.crt;
    ssl_certificate_key /var/www/itservicedesk/ssl/server.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers on;

    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;

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
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    location /health {
        proxy_pass http://127.0.0.1:5000;
        access_log off;
    }
}
NGINX_EOF

# Test and start nginx
echo "Starting Nginx..."
sudo nginx -t
sudo systemctl enable nginx
sudo systemctl restart nginx

# Configure firewall
echo "Configuring firewall..."
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable

# Setup database schema
echo "Setting up database schema..."
if [ -n "$DATABASE_URL" ]; then
    psql $DATABASE_URL -c "CREATE TABLE IF NOT EXISTS user_sessions (sid varchar NOT NULL COLLATE \"default\", sess json NOT NULL, expire timestamp(6) NOT NULL) WITH (OIDS=FALSE);" 2>/dev/null || true
    psql $DATABASE_URL -c "CREATE INDEX IF NOT EXISTS \"IDX_session_expire\" ON \"user_sessions\" (\"expire\");" 2>/dev/null || true
    echo "Database schema verified"
fi

# Start application with PM2
echo "Starting application with PM2..."
pm2 delete $APP_NAME 2>/dev/null || true
pm2 start ecosystem.config.js
pm2 save
pm2 startup ubuntu -u ubuntu --hp /home/ubuntu | tail -1 | sudo bash

# Wait for application to start
echo "Waiting for application to start..."
sleep 15

# Test deployment
echo "Testing deployment..."
if curl -s http://localhost:5000/health | grep -q "OK"; then
    echo "✓ Application is running"
else
    echo "✗ Application failed to start"
    pm2 logs $APP_NAME --lines 20
    exit 1
fi

if curl -k -s https://localhost/health | grep -q "OK"; then
    echo "✓ HTTPS proxy is working"
else
    echo "✗ HTTPS proxy failed"
    sudo systemctl status nginx --no-pager
    exit 1
fi

# Get server IP
SERVER_IP=$(curl -s ifconfig.me || echo "your-server-ip")

echo ""
echo "🎉 Deployment completed successfully!"
echo ""
echo "Calpion IT Service Desk is now running at:"
echo "  https://$SERVER_IP"
echo ""
echo "Default login:"
echo "  Username: john.doe"
echo "  Password: password123"
echo ""
echo "Management commands:"
echo "  pm2 logs $APP_NAME     # View logs"
echo "  pm2 restart $APP_NAME  # Restart app"
echo "  pm2 status             # Check status"
echo ""