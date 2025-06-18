# IT Service Desk - Clean Deployment Guide

## Overview

This guide provides clean deployment instructions for the IT Service Desk application on Ubuntu servers.

## Prerequisites

- Ubuntu 20.04+ server
- Root or sudo access
- Domain name or IP address

## Quick Deployment

### 1. Clone Repository
```bash
git clone <your-repo-url>
cd <repo-name>
```

### 2. Run Deployment Script
```bash
chmod +x deploy.sh
./deploy.sh
```

## Manual Deployment Steps

### 1. System Setup
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Node.js 20
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install PostgreSQL
sudo apt install -y postgresql postgresql-contrib

# Install Nginx
sudo apt install -y nginx

# Install PM2
sudo npm install -g pm2
```

### 2. Database Setup
```bash
# Start PostgreSQL
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Create database and user
sudo -u postgres psql << EOF
CREATE DATABASE servicedesk;
CREATE USER servicedesk WITH PASSWORD 'servicedesk123';
GRANT ALL PRIVILEGES ON DATABASE servicedesk TO servicedesk;
\q
EOF
```

### 3. Application Setup
```bash
# Install dependencies
npm install --production

# Build application
npm run build

# Set environment variables
cat > .env << EOF
DATABASE_URL=postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk
NODE_ENV=production
PORT=3000
EOF

# Run database migrations
npm run db:push
```

### 4. Process Management
```bash
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
      PORT: 3000
    }
  }]
};
EOF

# Start with PM2
pm2 start ecosystem.config.js
pm2 save
pm2 startup
```

### 5. Web Server Configuration
```bash
# Create Nginx configuration
sudo tee /etc/nginx/sites-available/servicedesk << EOF
server {
    listen 80;
    server_name your-domain.com;

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

# Enable site
sudo ln -s /etc/nginx/sites-available/servicedesk /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

### 6. Firewall Setup
```bash
# Configure UFW
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'
sudo ufw --force enable
```

## Environment Variables

For production deployment, create a `.env` file with:

```env
DATABASE_URL=postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk
NODE_ENV=production
PORT=3000
SENDGRID_API_KEY=your_sendgrid_api_key
```

## Verification

After deployment, verify the application is running:

```bash
# Check PM2 status
pm2 status

# Check application response
curl http://localhost:3000

# Check Nginx status
sudo systemctl status nginx

# Check logs
pm2 logs servicedesk
```

## Updates

To update the application:

```bash
# Pull latest changes
git pull origin main

# Install dependencies
npm install --production

# Rebuild
npm run build

# Restart PM2
pm2 restart servicedesk
```

## Troubleshooting

### Database Connection Issues
```bash
# Check PostgreSQL status
sudo systemctl status postgresql

# Test database connection
psql -h localhost -U servicedesk -d servicedesk -c "SELECT 1;"
```

### Application Not Starting
```bash
# Check PM2 logs
pm2 logs servicedesk

# Check environment variables
pm2 env servicedesk

# Restart application
pm2 restart servicedesk
```

### Nginx Issues
```bash
# Test configuration
sudo nginx -t

# Check logs
sudo tail -f /var/log/nginx/error.log

# Restart Nginx
sudo systemctl restart nginx
```