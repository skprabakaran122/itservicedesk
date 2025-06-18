#!/bin/bash

echo "IT Service Desk - Clean Deployment Script"
echo "=========================================="

# Exit on any error
set -e

# Configuration
DB_NAME="servicedesk"
DB_USER="servicedesk"
DB_PASS="servicedesk123"
APP_PORT="3000"

# 1. System Updates and Dependencies
echo "1. Installing system dependencies..."
sudo apt update -y

# Install curl first if missing
sudo apt install -y curl wget

# Get server IP or domain
if [ -z "$1" ]; then
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "localhost")
else
    SERVER_IP="$1"
fi

echo "Deploying to: $SERVER_IP"

# Install Node.js repository and packages
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs postgresql postgresql-contrib nginx

# Install PM2 globally
sudo npm install -g pm2

# 2. Database Setup
echo "2. Setting up PostgreSQL database..."
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Create database and user
sudo -u postgres psql << EOF
DROP DATABASE IF EXISTS $DB_NAME;
DROP USER IF EXISTS $DB_USER;
CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';
CREATE DATABASE $DB_NAME OWNER $DB_USER;
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
\q
EOF

echo "Database created successfully"

# 3. Application Setup
echo "3. Setting up application..."

# Install dependencies
npm install --production

# Create production environment file
cat > .env << EOF
DATABASE_URL=postgresql://$DB_USER:$DB_PASS@localhost:5432/$DB_NAME
NODE_ENV=production
PORT=$APP_PORT
EOF

# Build application
npm run build

# Run database migrations
npm run db:push

echo "Application built successfully"

# 4. PM2 Configuration
echo "4. Configuring process manager..."

# Create PM2 ecosystem file
cat > ecosystem.config.js << EOF
module.exports = {
  apps: [{
    name: '$DB_NAME',
    script: 'npm',
    args: 'start',
    cwd: process.cwd(),
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production',
      PORT: $APP_PORT,
      DATABASE_URL: 'postgresql://$DB_USER:$DB_PASS@localhost:5432/$DB_NAME'
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

echo "Application started with PM2"

# 5. SSL Certificate Setup
echo "5. Creating self-signed SSL certificate..."

# Create SSL directory
sudo mkdir -p /etc/nginx/ssl

# Generate self-signed certificate
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/servicedesk.key \
    -out /etc/nginx/ssl/servicedesk.crt \
    -subj "/C=US/ST=State/L=City/O=Calpion/OU=IT/CN=$SERVER_IP"

echo "SSL certificate created"

# 6. Nginx Configuration
echo "6. Configuring web server with HTTPS..."

# Create Nginx site configuration with SSL
sudo tee /etc/nginx/sites-available/$DB_NAME << EOF
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
        proxy_pass http://localhost:$APP_PORT;
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

# Enable site and restart Nginx
sudo ln -sf /etc/nginx/sites-available/$DB_NAME /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx

echo "Nginx configured successfully"

# 7. Firewall Setup
echo "7. Configuring firewall..."
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'
sudo ufw allow 443/tcp
sudo ufw allow 80/tcp
sudo ufw --force enable

echo "Firewall configured successfully"

# 8. Final Verification
echo "8. Verifying deployment..."

# Wait for application to start
sleep 10

# Test application
if curl -f http://localhost:$APP_PORT > /dev/null 2>&1; then
    echo "✅ Application is responding on port $APP_PORT"
else
    echo "❌ Application not responding - checking logs..."
    pm2 logs $DB_NAME --lines 20
    exit 1
fi

# Test HTTPS
if curl -k -f https://localhost > /dev/null 2>&1; then
    echo "✅ HTTPS is working with self-signed certificate"
else
    echo "❌ HTTPS not responding - checking Nginx..."
    sudo nginx -t
fi

# Test database
if psql -h localhost -U $DB_USER -d $DB_NAME -c "SELECT 1;" > /dev/null 2>&1; then
    echo "✅ Database connection successful"
else
    echo "❌ Database connection failed"
    exit 1
fi

# Test Nginx
if sudo nginx -t > /dev/null 2>&1; then
    echo "✅ Nginx configuration valid"
else
    echo "❌ Nginx configuration error"
    exit 1
fi

echo ""
echo "🎉 DEPLOYMENT COMPLETE!"
echo "=========================================="
echo "Application URLs:"
echo "- HTTPS (Secure): https://$SERVER_IP"
echo "- HTTP (Redirects): http://$SERVER_IP"
echo ""
echo "Services:"
echo "- Database: PostgreSQL on localhost:5432"
echo "- Process Manager: PM2"
echo "- Web Server: Nginx with SSL"
echo "- SSL Certificate: Self-signed (365 days)"
echo ""
echo "Management Commands:"
echo "- Check status: pm2 status"
echo "- View logs: pm2 logs $DB_NAME"
echo "- Restart app: pm2 restart $DB_NAME"
echo "- Update code: git pull && npm run build && pm2 restart $DB_NAME"
echo "- Check SSL: openssl x509 -in /etc/nginx/ssl/servicedesk.crt -text -noout"
echo ""
echo "Security Note:"
echo "Using self-signed certificate - browsers will show security warning"
echo "For production, replace with proper SSL certificate from CA"
echo ""
echo "Your IT Service Desk is now operational with HTTPS!"