# IT Service Desk - Ubuntu Server Deployment Guide

## Prerequisites

- Ubuntu 20.04 or 22.04 LTS server
- Root or sudo access
- Domain name (optional) or server IP address
- Port 80 and 443 access for web traffic

## Step 1: Server Preparation

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y nginx postgresql postgresql-contrib nodejs npm git curl

# Install Node.js 20 (recommended version)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install PM2 for process management
sudo npm install -g pm2

# Create application directory
sudo mkdir -p /var/www/servicedesk
sudo chown -R $USER:$USER /var/www/servicedesk
```

## Step 2: Database Setup

```bash
# Start PostgreSQL service
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Create database and user
sudo -u postgres psql << 'EOF'
CREATE USER servicedesk WITH PASSWORD 'your_secure_password_here';
CREATE DATABASE servicedesk OWNER servicedesk;
GRANT ALL PRIVILEGES ON DATABASE servicedesk TO servicedesk;
ALTER USER servicedesk CREATEDB;
\q
EOF

# Configure PostgreSQL for local connections
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = 'localhost'/" /etc/postgresql/*/main/postgresql.conf
sudo systemctl restart postgresql
```

## Step 3: Application Deployment

```bash
# Clone your application (replace with your repository)
cd /var/www/servicedesk
git clone https://github.com/yourusername/servicedesk.git .

# Install dependencies
npm install

# Create environment configuration
cat > .env << 'EOF'
DATABASE_URL=postgresql://servicedesk:your_secure_password_here@localhost:5432/servicedesk
NODE_ENV=production
PORT=3000
SENDGRID_API_KEY=your_sendgrid_api_key_here
EOF

# Run database migrations
npm run db:push

# Build the application
npm run build

# Test the application
npm start &
sleep 5
curl http://localhost:3000
pkill -f "tsx.*server/index.ts"
```

## Step 4: Process Management with PM2

```bash
# Create PM2 ecosystem file
cat > ecosystem.config.js << 'EOF'
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

# Start application with PM2
pm2 start ecosystem.config.js
pm2 save
pm2 startup
```

## Step 5: Nginx Configuration

```bash
# Create Nginx configuration
sudo tee /etc/nginx/sites-available/servicedesk << 'EOF'
server {
    listen 80;
    server_name your_domain.com;  # Replace with your domain or server IP

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    # Serve static files directly
    location /static/ {
        alias /var/www/servicedesk/dist/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

# Enable the site
sudo ln -s /etc/nginx/sites-available/servicedesk /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

## Step 6: SSL Certificate (Optional but Recommended)

### Option A: Let's Encrypt (Free SSL)

```bash
# Install Certbot
sudo apt install -y certbot python3-certbot-nginx

# Get SSL certificate
sudo certbot --nginx -d your_domain.com

# Auto-renewal
sudo crontab -e
# Add this line:
# 0 12 * * * /usr/bin/certbot renew --quiet
```

### Option B: Self-Signed Certificate

```bash
# Create SSL directory
sudo mkdir -p /etc/nginx/ssl

# Generate certificate
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/servicedesk.key \
    -out /etc/nginx/ssl/servicedesk.crt \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=your_domain.com"

# Update Nginx configuration for HTTPS
sudo tee /etc/nginx/sites-available/servicedesk << 'EOF'
server {
    listen 80;
    server_name your_domain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl;
    server_name your_domain.com;

    ssl_certificate /etc/nginx/ssl/servicedesk.crt;
    ssl_certificate_key /etc/nginx/ssl/servicedesk.key;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF

sudo nginx -t && sudo systemctl restart nginx
```

## Step 7: Firewall Configuration

```bash
# Configure UFW firewall
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable
```

## Step 8: Monitoring and Maintenance

```bash
# Check application status
pm2 status
pm2 logs servicedesk

# Check Nginx status
sudo systemctl status nginx

# Check database status
sudo systemctl status postgresql

# Monitor logs
sudo tail -f /var/log/servicedesk/combined.log
sudo tail -f /var/log/nginx/access.log
```

## Step 9: Updates and Maintenance

```bash
# Create update script
cat > update.sh << 'EOF'
#!/bin/bash
cd /var/www/servicedesk
git pull origin main
npm install
npm run build
npm run db:push
pm2 restart servicedesk
EOF

chmod +x update.sh
```

## Troubleshooting

### Common Issues:

1. **Database Connection Error**
   ```bash
   # Check PostgreSQL status
   sudo systemctl status postgresql
   # Check database connectivity
   psql -U servicedesk -d servicedesk -h localhost
   ```

2. **Application Won't Start**
   ```bash
   # Check PM2 logs
   pm2 logs servicedesk
   # Check application directly
   cd /var/www/servicedesk && npm start
   ```

3. **Nginx Issues**
   ```bash
   # Test configuration
   sudo nginx -t
   # Check error logs
   sudo tail -f /var/log/nginx/error.log
   ```

## Security Recommendations

1. **Database Security**
   - Use strong passwords
   - Limit database access to localhost only
   - Regular backups

2. **Application Security**
   - Keep Node.js and dependencies updated
   - Use environment variables for secrets
   - Enable HTTPS

3. **Server Security**
   - Regular system updates
   - Firewall configuration
   - SSH key authentication
   - Fail2ban for brute force protection

## Backup Strategy

```bash
# Database backup script
cat > backup.sh << 'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
pg_dump -U servicedesk -h localhost servicedesk > /var/backups/servicedesk_$DATE.sql
find /var/backups -name "servicedesk_*.sql" -mtime +7 -delete
EOF

chmod +x backup.sh

# Add to crontab for daily backups
echo "0 2 * * * /var/www/servicedesk/backup.sh" | sudo crontab -
```

Your IT Service Desk will be accessible at:
- HTTP: http://your_domain.com or http://your_server_ip
- HTTPS: https://your_domain.com or https://your_server_ip (if SSL configured)