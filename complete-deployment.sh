#!/bin/bash

echo "Completing IT Service Desk Deployment"
echo "====================================="

# Get server IP
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}' || echo "localhost")
echo "Server IP: $SERVER_IP"

# Database setup
echo "Setting up database..."
sudo -u postgres psql << EOF
DROP DATABASE IF EXISTS servicedesk;
DROP USER IF EXISTS servicedesk;
CREATE USER servicedesk WITH PASSWORD 'servicedesk123';
CREATE DATABASE servicedesk OWNER servicedesk;
GRANT ALL PRIVILEGES ON DATABASE servicedesk TO servicedesk;
\q
EOF

# Application setup
echo "Setting up application..."

# Create environment file
cat > .env << EOF
DATABASE_URL=postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk
NODE_ENV=production
PORT=3000
EOF

# Install dependencies and build
npm install --production
npm run build
npm run db:push

# Create PM2 ecosystem file
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

# Start application with PM2
pm2 start ecosystem.config.js
pm2 save
pm2 startup

echo "Application started"

# SSL Certificate setup
echo "Setting up SSL certificate..."
sudo mkdir -p /etc/nginx/ssl

sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/servicedesk.key \
    -out /etc/nginx/ssl/servicedesk.crt \
    -subj "/C=US/ST=State/L=City/O=Calpion/OU=IT/CN=$SERVER_IP"

echo "SSL certificate created"

# Nginx configuration
echo "Configuring Nginx..."

sudo tee /etc/nginx/sites-available/servicedesk << EOF
# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name $SERVER_IP;
    return 301 https://\$server_name\$request_uri;
}

# HTTPS server
server {
    listen 443 ssl http2;
    server_name $SERVER_IP;

    # SSL Configuration
    ssl_certificate /etc/nginx/ssl/servicedesk.crt;
    ssl_certificate_key /etc/nginx/ssl/servicedesk.key;
    
    # SSL Security Settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_timeout 10m;
    ssl_session_cache shared:SSL:10m;
    
    # Security Headers
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;

    # Application Proxy
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
        proxy_redirect off;
    }

    client_max_body_size 10M;
}
EOF

# Enable site
sudo ln -sf /etc/nginx/sites-available/servicedesk /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx

echo "Nginx configured"

# Firewall setup
echo "Configuring firewall..."
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'
sudo ufw allow 443/tcp
sudo ufw allow 80/tcp
sudo ufw --force enable

echo "Firewall configured"

# Verification
echo ""
echo "Testing deployment..."
sleep 5

if curl -f http://localhost:3000 > /dev/null 2>&1; then
    echo "✓ Application running on port 3000"
else
    echo "✗ Application not responding - checking logs..."
    pm2 logs servicedesk --lines 10
fi

if curl -k -f https://localhost > /dev/null 2>&1; then
    echo "✓ HTTPS working"
else
    echo "✗ HTTPS not working - checking Nginx..."
    sudo nginx -t
fi

if sudo nginx -t > /dev/null 2>&1; then
    echo "✓ Nginx configuration valid"
else
    echo "✗ Nginx configuration error"
fi

echo ""
echo "🎉 DEPLOYMENT COMPLETE!"
echo "======================================"
echo "Your IT Service Desk is now available at:"
echo "https://$SERVER_IP"
echo ""
echo "Default login:"
echo "Username: john.doe"
echo "Password: password123"
echo ""
echo "Management commands:"
echo "pm2 status                    # Check application status"
echo "pm2 logs servicedesk         # View application logs"
echo "pm2 restart servicedesk      # Restart application"
echo "sudo systemctl status nginx  # Check web server"
echo ""
echo "Note: Browser will show security warning for self-signed certificate"
echo "Click 'Advanced' then 'Proceed' to access the application"