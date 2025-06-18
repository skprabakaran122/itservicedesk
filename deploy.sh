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

# Get server IP or domain
if [ -z "$1" ]; then
    SERVER_IP=$(curl -s ifconfig.me || echo "localhost")
else
    SERVER_IP="$1"
fi

echo "Deploying to: $SERVER_IP"

# 1. System Updates and Dependencies
echo "1. Installing system dependencies..."
sudo apt update -y
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

# 5. Nginx Configuration
echo "5. Configuring web server..."

# Create Nginx site configuration
sudo tee /etc/nginx/sites-available/$DB_NAME << EOF
server {
    listen 80;
    server_name $SERVER_IP;

    location / {
        proxy_pass http://localhost:$APP_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }

    client_max_body_size 10M;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
}
EOF

# Enable site and restart Nginx
sudo ln -sf /etc/nginx/sites-available/$DB_NAME /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx

echo "Nginx configured successfully"

# 6. Firewall Setup
echo "6. Configuring firewall..."
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'
sudo ufw --force enable

echo "Firewall configured successfully"

# 7. Final Verification
echo "7. Verifying deployment..."

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
echo "Application URL: http://$SERVER_IP"
echo "Database: PostgreSQL on localhost:5432"
echo "Process Manager: PM2"
echo "Web Server: Nginx"
echo ""
echo "Management Commands:"
echo "- Check status: pm2 status"
echo "- View logs: pm2 logs $DB_NAME"
echo "- Restart app: pm2 restart $DB_NAME"
echo "- Update code: git pull && npm run build && pm2 restart $DB_NAME"
echo ""
echo "Your IT Service Desk is now operational!"