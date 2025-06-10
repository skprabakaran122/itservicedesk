# IT Service Desk Deployment Guide for Ubuntu

This guide will help you deploy the IT Service Desk application on an Ubuntu machine.

## Prerequisites

- Ubuntu 20.04 LTS or newer
- Sudo access
- Internet connection

## Step 1: System Updates and Dependencies

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install essential packages
sudo apt install -y curl wget git build-essential
```

## Step 2: Install Node.js 20

```bash
# Install Node.js 20 using NodeSource repository
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Verify installation
node --version
npm --version
```

## Step 3: Install PostgreSQL

```bash
# Install PostgreSQL
sudo apt install -y postgresql postgresql-contrib

# Start and enable PostgreSQL service
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Create database and user
sudo -u postgres psql << EOF
CREATE DATABASE servicedesk;
CREATE USER servicedesk_user WITH PASSWORD 'your_secure_password';
GRANT ALL PRIVILEGES ON DATABASE servicedesk TO servicedesk_user;
ALTER USER servicedesk_user CREATEDB;
\q
EOF
```

## Step 4: Clone and Setup Application

```bash
# Clone the repository (replace with your actual repository URL)
git clone <your-repository-url> servicedesk
cd servicedesk

# Install dependencies
npm install

# Install TypeScript globally for tsx
npm install -g tsx typescript

# Create environment file
cat > .env << EOF
DATABASE_URL=postgresql://servicedesk_user:your_secure_password@localhost:5432/servicedesk
NODE_ENV=production
PORT=5000
SESSION_SECRET=your_very_secure_session_secret_here
EOF
```

## Step 5: Database Setup

```bash
# Push database schema
npm run db:push

# Verify database connection
npm run db:check || echo "Database schema created successfully"
```

## Step 6: Build Application

```bash
# Build the frontend
npm run build

# Test the application
npm run dev
```

## Step 7: Production Setup with PM2

```bash
# Install PM2 process manager
sudo npm install -g pm2

# Create PM2 ecosystem file
cat > ecosystem.config.js << EOF
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'npm',
    args: 'run dev',
    cwd: '/path/to/your/servicedesk',
    env: {
      NODE_ENV: 'production',
      PORT: 5000
    },
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    error_file: './logs/err.log',
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

# Save PM2 configuration
pm2 save

# Setup PM2 to start on system boot
pm2 startup
# Follow the instructions provided by the command above
```

## Step 8: Configure Nginx (Optional)

```bash
# Install Nginx
sudo apt install -y nginx

# Create Nginx configuration
sudo tee /etc/nginx/sites-available/servicedesk << EOF
server {
    listen 80;
    server_name your-domain.com;  # Replace with your domain

    location / {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

# Enable the site
sudo ln -s /etc/nginx/sites-available/servicedesk /etc/nginx/sites-enabled/

# Test Nginx configuration
sudo nginx -t

# Restart Nginx
sudo systemctl restart nginx
sudo systemctl enable nginx
```

## Step 9: Configure Firewall

```bash
# Configure UFW firewall
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw allow 5000  # Direct access (optional)
sudo ufw --force enable

# Check firewall status
sudo ufw status
```

## Step 10: SSL Certificate with Let's Encrypt (Optional)

```bash
# Install Certbot
sudo apt install -y certbot python3-certbot-nginx

# Obtain SSL certificate (replace with your domain)
sudo certbot --nginx -d your-domain.com

# Test automatic renewal
sudo certbot renew --dry-run
```

## Step 11: Monitor and Manage

```bash
# Check application status
pm2 status
pm2 logs servicedesk

# Monitor system resources
pm2 monit

# Restart application
pm2 restart servicedesk

# Stop application
pm2 stop servicedesk

# View application logs
tail -f logs/combined.log
```

## Step 12: Database Backup Setup

```bash
# Create backup script
sudo tee /etc/cron.daily/servicedesk-backup << 'EOF'
#!/bin/bash
BACKUP_DIR="/var/backups/servicedesk"
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p $BACKUP_DIR

# Database backup
sudo -u postgres pg_dump servicedesk > $BACKUP_DIR/servicedesk_$DATE.sql

# Keep only last 7 days of backups
find $BACKUP_DIR -name "servicedesk_*.sql" -mtime +7 -delete

echo "Backup completed: $DATE"
EOF

# Make backup script executable
sudo chmod +x /etc/cron.daily/servicedesk-backup
```

## Troubleshooting

### Common Issues:

1. **Database Connection Issues:**
   ```bash
   # Check PostgreSQL status
   sudo systemctl status postgresql
   
   # Check database connectivity
   psql -h localhost -U servicedesk_user -d servicedesk
   ```

2. **Port Already in Use:**
   ```bash
   # Check what's using port 5000
   sudo lsof -i :5000
   
   # Kill process if needed
   sudo kill -9 <PID>
   ```

3. **Permission Issues:**
   ```bash
   # Fix ownership
   sudo chown -R $USER:$USER /path/to/servicedesk
   
   # Fix permissions
   chmod -R 755 /path/to/servicedesk
   ```

4. **Node.js Memory Issues:**
   ```bash
   # Increase Node.js memory limit
   export NODE_OPTIONS="--max-old-space-size=4096"
   ```

## Application URLs

- Application: http://your-server-ip:5000 (or https://your-domain.com with Nginx)
- Admin Console: Login with admin credentials
- SLA Dashboard: Available in the admin section

## Default Credentials

- Admin: john.doe / password123
- Agent: jane.smith / password123
- Manager: skprabakaran122 / password123

**Important:** Change these default passwords immediately after deployment!

## Security Recommendations

1. Change all default passwords
2. Update SESSION_SECRET in .env file
3. Configure proper firewall rules
4. Enable SSL certificates
5. Regular system and application updates
6. Monitor application logs
7. Setup automated backups

## Maintenance

- Monitor disk space: `df -h`
- Monitor memory usage: `free -h`
- Check application logs: `pm2 logs`
- Update dependencies: `npm audit && npm update`
- Database maintenance: Regular backups and cleanup

For support, check the application logs and system resources first. The application includes comprehensive error logging and monitoring capabilities.