#!/bin/bash

# Simple, reliable IT Service Desk deployment
echo "=== IT Service Desk - Clean Deployment ==="
echo ""

set -e  # Exit on any error

# Get basic information
read -p "Server domain/IP (default: $(hostname -I | awk '{print $1}')): " SERVER_DOMAIN
SERVER_DOMAIN=${SERVER_DOMAIN:-$(hostname -I | awk '{print $1}')}

echo "Installing IT Service Desk on: $SERVER_DOMAIN"
echo ""

# System preparation
echo "1. Installing system requirements..."
sudo apt update
sudo apt install -y curl wget git

# Install Node.js 20
if ! command -v node &> /dev/null || [[ $(node --version) != v20* ]]; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

# Install global packages
sudo npm install -g pm2 tsx

# PostgreSQL setup
echo "2. Setting up PostgreSQL..."
sudo apt install -y postgresql postgresql-contrib
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Create database with simple credentials
DB_PASSWORD="servicedesk123"
sudo -u postgres psql << EOF
DROP DATABASE IF EXISTS servicedesk;
DROP USER IF EXISTS servicedesk;
CREATE USER servicedesk WITH PASSWORD '$DB_PASSWORD' SUPERUSER;
CREATE DATABASE servicedesk OWNER servicedesk;
\q
EOF

# Nginx setup
echo "3. Setting up Nginx..."
sudo apt install -y nginx
sudo systemctl start nginx
sudo systemctl enable nginx

# Application setup
echo "4. Setting up application..."
sudo mkdir -p /var/www/servicedesk
sudo chown -R $USER:$USER /var/www/servicedesk
cd /var/www/servicedesk

# Copy application files (assuming they're in current directory)
if [ -f "../package.json" ]; then
    cp -r ../* . 2>/dev/null || true
else
    echo "Please ensure application files are in the deployment directory"
    exit 1
fi

# Install dependencies
npm install

# Create environment file with working configuration
cat > .env << EOF
DATABASE_URL=postgresql://servicedesk:$DB_PASSWORD@localhost:5432/servicedesk
NODE_ENV=production
PORT=3000
EOF

# Fix the database connection issue by modifying server/db.ts
echo "5. Fixing environment variable loading..."
if [ -f "server/db.ts" ]; then
    # Backup original
    cp server/db.ts server/db.ts.original
    
    # Create new version with dotenv at top
    cat > server/db.ts << 'EOF'
import { config } from 'dotenv';
config();

import { Pool, neonConfig } from '@neondatabase/serverless';
import { drizzle } from 'drizzle-orm/neon-serverless';
import ws from "ws";
import * as schema from "@shared/schema";

neonConfig.webSocketConstructor = ws;

if (!process.env.DATABASE_URL) {
  throw new Error(
    "DATABASE_URL must be set. Did you forget to provision a database?",
  );
}

export const pool = new Pool({ connectionString: process.env.DATABASE_URL });
export const db = drizzle({ client: pool, schema });
EOF
fi

# Run database migrations
echo "6. Running database setup..."
npm run db:push

# Build application
echo "7. Building application..."
npm run build

# Create PM2 configuration
cat > ecosystem.config.cjs << 'EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'tsx',
    args: 'server/index.ts',
    cwd: '/var/www/servicedesk',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    error_file: '/var/log/servicedesk/error.log',
    out_file: '/var/log/servicedesk/out.log',
    log_file: '/var/log/servicedesk/combined.log',
    time: true
  }]
};
EOF

# Create log directory
sudo mkdir -p /var/log/servicedesk
sudo chown -R $USER:$USER /var/log/servicedesk

# Configure Nginx
echo "8. Configuring web server..."
sudo tee /etc/nginx/sites-available/servicedesk << EOF
server {
    listen 80;
    server_name $SERVER_DOMAIN;

    location / {
        proxy_pass http://localhost:3000;
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
}
EOF

sudo ln -sf /etc/nginx/sites-available/servicedesk /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl restart nginx

# Start application
echo "9. Starting application..."
pm2 start ecosystem.config.cjs
pm2 save
pm2 startup | grep "sudo.*systemctl" | bash || true

# Firewall configuration
echo "10. Configuring firewall..."
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable

# Final verification
echo "11. Verifying installation..."
sleep 5

if curl -s http://localhost:3000 > /dev/null; then
    echo "✅ SUCCESS! IT Service Desk is running"
    echo ""
    echo "Access your application at: http://$SERVER_DOMAIN"
    echo "Default admin login: admin / admin"
    echo ""
    echo "Management commands:"
    echo "  pm2 status              - Check status"
    echo "  pm2 logs servicedesk    - View logs"
    echo "  pm2 restart servicedesk - Restart app"
    echo ""
else
    echo "❌ Application not responding. Checking logs..."
    pm2 logs servicedesk --lines 10
fi