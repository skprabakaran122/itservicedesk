#!/bin/bash

echo "Quick Deployment - IT Service Desk"
echo "=================================="

# Run a streamlined deployment that handles the issues we saw
set -e

# Basic setup
sudo apt update -y
sudo apt install -y curl wget gnupg software-properties-common screen

# Get server IP
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}' || echo "localhost")
echo "Deploying to: $SERVER_IP"

# Remove old Node.js completely
sudo apt remove --purge -y nodejs npm || true
sudo rm -rf /usr/local/bin/node /usr/local/bin/npm /usr/local/lib/node_modules

# Install Node.js 20
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Verify installation
echo "Node.js: $(node --version)"
echo "npm: $(npm --version)"

# Install other packages
sudo apt install -y postgresql postgresql-contrib nginx

# Install PM2
sudo npm install -g pm2

# Database setup
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Create database
sudo -u postgres psql << EOF
DROP DATABASE IF EXISTS servicedesk;
DROP USER IF EXISTS servicedesk;
CREATE USER servicedesk WITH PASSWORD 'servicedesk123';
CREATE DATABASE servicedesk OWNER servicedesk;
GRANT ALL PRIVILEGES ON DATABASE servicedesk TO servicedesk;
\q
EOF

# Application setup
npm install --production

# Create environment
cat > .env << EOF
DATABASE_URL=postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk
NODE_ENV=production
PORT=3000
EOF

# Build application
npm run build

# Database schema
npm run db:push

# Create PM2 config
cat > ecosystem.config.js << EOF
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'npm',
    args: 'start',
    cwd: process.cwd(),
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production',
      PORT: 3000,
      DATABASE_URL: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk'
    },
    error_file: './logs/error.log',
    out_file: './logs/out.log',
    log_file: './logs/combined.log',
    time: true
  }]
};
EOF

# Create logs directory
mkdir -p logs

# Start application
pm2 start ecosystem.config.js
pm2 save
pm2 startup

# SSL Certificate
sudo mkdir -p /etc/nginx/ssl
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/servicedesk.key \
    -out /etc/nginx/ssl/servicedesk.crt \
    -subj "/C=US/ST=State/L=City/O=Calpion/OU=IT/CN=$SERVER_IP"

# Nginx configuration
sudo tee /etc/nginx/sites-available/servicedesk << EOF
server {
    listen 80;
    server_name $SERVER_IP;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $SERVER_IP;

    ssl_certificate /etc/nginx/ssl/servicedesk.crt;
    ssl_certificate_key /etc/nginx/ssl/servicedesk.key;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;
    
    add_header Strict-Transport-Security "max-age=63072000" always;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_cache_bypass \$http_upgrade;
    }

    client_max_body_size 10M;
}
EOF

# Enable site
sudo ln -sf /etc/nginx/sites-available/servicedesk /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx

# Firewall
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'
sudo ufw --force enable

# Test
sleep 5
echo ""
echo "Testing deployment..."
if curl -f http://localhost:3000 > /dev/null 2>&1; then
    echo "✓ Application running on port 3000"
else
    echo "✗ Application not responding"
    pm2 logs servicedesk --lines 10
fi

if curl -k -f https://localhost > /dev/null 2>&1; then
    echo "✓ HTTPS working"
else
    echo "✗ HTTPS not working"
fi

echo ""
echo "🎉 DEPLOYMENT COMPLETE!"
echo "======================================"
echo "Access your IT Service Desk at:"
echo "https://$SERVER_IP"
echo ""
echo "Management:"
echo "pm2 status"
echo "pm2 logs servicedesk"
echo "pm2 restart servicedesk"
EOF