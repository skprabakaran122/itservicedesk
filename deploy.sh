#!/bin/bash

# Production Deployment Script for Calpion IT Service Desk
# Ubuntu + Nginx HTTPS + PM2

set -e

APP_NAME="itservicedesk"
APP_DIR="/var/www/$APP_NAME"
NGINX_CONF="/etc/nginx/sites-available/default"
SSL_DIR="$APP_DIR/ssl"

echo "🚀 Starting production deployment..."

# Update system and install dependencies
echo "📦 Installing system dependencies..."
sudo apt update
sudo apt install -y nginx nodejs npm postgresql-client curl

# Install PM2 globally
if ! command -v pm2 &> /dev/null; then
    echo "📦 Installing PM2..."
    sudo npm install -g pm2
fi

# Create application directory
echo "📁 Setting up application directory..."
sudo mkdir -p $APP_DIR
sudo chown -R ubuntu:ubuntu $APP_DIR

# Clone or copy application
if [ -d ".git" ]; then
    echo "📋 Copying application from current directory..."
    rsync -av --exclude=node_modules --exclude=.git --exclude=dist . $APP_DIR/
else
    echo "📥 Cloning from repository..."
    git clone https://github.com/skprabakaran122/itservicedesk.git $APP_DIR
fi

cd $APP_DIR

# Install dependencies
echo "📦 Installing Node.js dependencies..."
npm install --production=false

# Build frontend
echo "🔨 Building frontend..."
npm run build

# Copy production server (CommonJS for PM2 compatibility)
echo "🔨 Preparing production server..."
mkdir -p dist
cp server/production.cjs dist/production.cjs

# Create logs directory
mkdir -p logs

# Setup SSL certificates
echo "🔒 Setting up SSL certificates..."
mkdir -p $SSL_DIR
cd $SSL_DIR

if [ ! -f "server.crt" ]; then
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout server.key -out server.crt \
        -subj "/C=US/ST=CA/L=San Francisco/O=Calpion/CN=$(curl -s ifconfig.me)" \
        -addext "subjectAltName=IP:$(curl -s ifconfig.me)"
    echo "✅ SSL certificates created"
fi

cd $APP_DIR

# Configure Nginx
echo "🌐 Configuring Nginx..."
sudo tee $NGINX_CONF > /dev/null << 'NGINX_EOF'
# HTTP to HTTPS redirect
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    return 301 https://$host$request_uri;
}

# HTTPS server
server {
    listen 443 ssl http2 default_server;
    listen [::]:443 ssl http2 default_server;
    server_name _;

    # SSL Configuration
    ssl_certificate /var/www/itservicedesk/ssl/server.crt;
    ssl_certificate_key /var/www/itservicedesk/ssl/server.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;

    # Security headers
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Proxy to Node.js application
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

    # Health check
    location /health {
        proxy_pass http://127.0.0.1:5000;
        access_log off;
    }
}
NGINX_EOF

# Test nginx configuration
echo "🔍 Testing Nginx configuration..."
sudo nginx -t

# Configure firewall
echo "🔥 Configuring firewall..."
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable

# Start/restart services
echo "🔄 Starting services..."
sudo systemctl enable nginx
sudo systemctl restart nginx

# Stop any existing PM2 processes
pm2 delete $APP_NAME 2>/dev/null || true

# Start application with PM2
echo "🚀 Starting application with PM2..."
pm2 start ecosystem.config.js
pm2 save
pm2 startup

# Wait for application to start
sleep 10

# Test application
echo "🔍 Testing application..."
if curl -s http://localhost:5000/health | grep -q "OK"; then
    echo "✅ Application is running on port 5000"
else
    echo "❌ Application failed to start"
    pm2 logs $APP_NAME --lines 20
    exit 1
fi

if curl -k -s https://localhost/health | grep -q "OK"; then
    echo "✅ HTTPS proxy is working"
else
    echo "❌ HTTPS proxy failed"
    sudo systemctl status nginx --no-pager
    exit 1
fi

# Get server IP
SERVER_IP=$(curl -s ifconfig.me)

echo ""
echo "🎉 Deployment completed successfully!"
echo ""
echo "Access your Calpion IT Service Desk at:"
echo "  https://$SERVER_IP"
echo ""
echo "Default login credentials:"
echo "  Username: john.doe"
echo "  Password: password123"
echo ""
echo "Management commands:"
echo "  View logs: pm2 logs $APP_NAME"
echo "  Restart: pm2 restart $APP_NAME"
echo "  Stop: pm2 stop $APP_NAME"
echo "  Status: pm2 status"
echo ""