# Ubuntu AWS Production Deployment Guide

Complete guide for deploying the IT Service Desk application on Ubuntu with AWS RDS.

## Prerequisites

### AWS RDS Setup
1. Create PostgreSQL RDS instance
2. Configure security groups for database access
3. Note down endpoint, username, password, and database name

### Ubuntu Server Setup
- Ubuntu 20.04 LTS or 22.04 LTS
- Minimum 2GB RAM, 20GB storage
- SSH access with sudo privileges
- Domain name pointed to server IP (for SSL)

## Quick Deployment

### 1. Basic Application Deployment
```bash
# Make deployment script executable
chmod +x deploy-ubuntu-aws.sh

# Run deployment (will install all dependencies)
./deploy-ubuntu-aws.sh
```

### 2. Configure RDS Connection
```bash
# Edit environment file with your RDS details
sudo nano /opt/itservicedesk/.env

# Update these values:
DATABASE_URL=postgresql://username:password@your-rds-endpoint.region.rds.amazonaws.com:5432/itservicedesk?sslmode=require
DB_HOST=your-rds-endpoint.region.rds.amazonaws.com
DB_NAME=itservicedesk
DB_USER=your_db_username
DB_PASSWORD=your_db_password
```

### 3. Restart Application
```bash
# Restart application with new configuration
sudo systemctl restart itservicedesk

# Run database migrations
cd /opt/itservicedesk
node migrations/run_migrations.cjs
```

### 4. Setup SSL (Optional but Recommended)
```bash
# Setup SSL with Let's Encrypt
chmod +x ubuntu-ssl-setup.sh
./ubuntu-ssl-setup.sh yourdomain.com admin@yourdomain.com
```

### 5. Enable Monitoring (Recommended)
```bash
# Setup monitoring and health checks
chmod +x ubuntu-monitoring.sh
./ubuntu-monitoring.sh
```

## Manual Installation Steps

### 1. System Dependencies
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Node.js 20
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Install PM2 and other tools
sudo npm install -g pm2 tsx
sudo apt install -y nginx postgresql-client
```

### 2. Application Setup
```bash
# Create application directory
sudo mkdir -p /opt/itservicedesk
sudo chown ubuntu:ubuntu /opt/itservicedesk

# Copy application files
cp -r . /opt/itservicedesk/
cd /opt/itservicedesk

# Install dependencies
npm ci --production
```

### 3. Environment Configuration
```bash
# Create production environment file
cat > /opt/itservicedesk/.env << EOF
NODE_ENV=production
PORT=5000
HOST=0.0.0.0

# RDS Configuration
DATABASE_URL=postgresql://username:password@rds-endpoint:5432/itservicedesk?sslmode=require
DB_SSL_MODE=require

# File Storage
UPLOAD_DIR=/opt/itservicedesk/uploads

# Security
SESSION_SECRET=$(openssl rand -base64 32)
EOF
```

### 4. PM2 Configuration
```bash
# Create PM2 ecosystem file
cat > ecosystem.config.cjs << 'EOF'
module.exports = {
  apps: [{
    name: 'itservicedesk',
    script: 'tsx',
    args: 'server/index.ts',
    instances: 1,
    autorestart: true,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production'
    }
  }]
};
EOF
```

### 5. Nginx Configuration
```bash
# Create Nginx site configuration
sudo tee /etc/nginx/sites-available/itservicedesk << 'EOF'
server {
    listen 80;
    server_name _;
    
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Enable site
sudo ln -s /etc/nginx/sites-available/itservicedesk /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx
```

### 6. Systemd Service
```bash
# Create systemd service
sudo tee /etc/systemd/system/itservicedesk.service << 'EOF'
[Unit]
Description=IT Service Desk Application
After=network.target

[Service]
Type=forking
User=ubuntu
WorkingDirectory=/opt/itservicedesk
ExecStart=/usr/bin/pm2 start ecosystem.config.cjs --env production
ExecStop=/usr/bin/pm2 stop ecosystem.config.cjs
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable itservicedesk
sudo systemctl start itservicedesk
```

## Management Commands

### Application Management
```bash
# Check application status
sudo systemctl status itservicedesk
pm2 status

# View logs
pm2 logs itservicedesk
tail -f /opt/itservicedesk/logs/combined.log

# Restart application
sudo systemctl restart itservicedesk
pm2 restart itservicedesk

# Stop/start application
sudo systemctl stop itservicedesk
sudo systemctl start itservicedesk
```

### Database Operations
```bash
# Run migrations
cd /opt/itservicedesk
node migrations/run_migrations.cjs

# Connect to RDS database
psql -h your-rds-endpoint.region.rds.amazonaws.com -U username -d itservicedesk

# Backup database
pg_dump -h your-rds-endpoint.region.rds.amazonaws.com -U username itservicedesk > backup.sql

# Restore database
psql -h your-rds-endpoint.region.rds.amazonaws.com -U username itservicedesk < backup.sql
```

### System Monitoring
```bash
# View status dashboard
sudo /usr/local/bin/itservice-status.sh

# Check health
curl http://localhost/health

# Monitor resources
htop
df -h
free -h

# Check fail2ban status
sudo fail2ban-client status
```

## Security Configuration

### Firewall Setup
```bash
# Configure UFW firewall
sudo ufw enable
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'
sudo ufw status
```

### SSL Certificate (Let's Encrypt)
```bash
# Install Certbot
sudo snap install --classic certbot

# Obtain certificate
sudo certbot --nginx -d yourdomain.com

# Test auto-renewal
sudo certbot renew --dry-run
```

### Fail2ban Configuration
```bash
# Configure SSH protection
sudo tee /etc/fail2ban/jail.local << 'EOF'
[sshd]
enabled = true
maxretry = 3
bantime = 3600
EOF

sudo systemctl restart fail2ban
```

## Troubleshooting

### Common Issues

**Application won't start:**
```bash
# Check logs
pm2 logs itservicedesk
sudo journalctl -u itservicedesk -f

# Check configuration
sudo nginx -t
pm2 status
```

**Database connection issues:**
```bash
# Test RDS connectivity
telnet your-rds-endpoint.region.rds.amazonaws.com 5432

# Check environment variables
cat /opt/itservicedesk/.env

# Test database connection
cd /opt/itservicedesk
node -e "require('dotenv').config(); const {Pool} = require('pg'); const pool = new Pool({connectionString: process.env.DATABASE_URL}); pool.query('SELECT 1').then(() => console.log('Connected')).catch(console.error);"
```

**SSL certificate issues:**
```bash
# Check certificate status
sudo certbot certificates

# Renew certificates
sudo certbot renew

# Check Nginx SSL configuration
sudo nginx -t
```

**Performance issues:**
```bash
# Monitor resources
htop
iotop
pm2 monit

# Check application metrics
curl http://localhost/health
pm2 logs itservicedesk
```

### Log Locations
- Application logs: `/opt/itservicedesk/logs/`
- PM2 logs: `~/.pm2/logs/`
- Nginx logs: `/var/log/nginx/`
- System logs: `/var/log/syslog`
- Monitor logs: `/var/log/itservicedesk-monitor.log`

## Backup and Recovery

### Automated Backups
```bash
# Backup script runs daily at 2 AM
sudo /usr/local/bin/itservice-backup.sh

# Check backup files
ls -la /backup/itservicedesk/
```

### Manual Backup
```bash
# Backup application
tar -czf itservice-backup-$(date +%Y%m%d).tar.gz -C /opt itservicedesk

# Backup database
pg_dump $DATABASE_URL > database-backup-$(date +%Y%m%d).sql
```

### Recovery
```bash
# Restore application
sudo systemctl stop itservicedesk
sudo tar -xzf itservice-backup-*.tar.gz -C /opt/
sudo systemctl start itservicedesk

# Restore database
psql $DATABASE_URL < database-backup-*.sql
```

## Performance Optimization

### PM2 Cluster Mode
```bash
# Edit ecosystem.config.cjs for multiple instances
instances: 'max',  # or specific number
exec_mode: 'cluster'
```

### Nginx Optimization
```bash
# Add to nginx configuration
worker_processes auto;
worker_connections 1024;
gzip on;
gzip_types text/plain application/json;
```

### Database Optimization
- Configure RDS parameter groups
- Enable connection pooling
- Monitor slow queries
- Set up read replicas if needed

## Monitoring and Alerts

### Built-in Monitoring
- Health checks every 5 minutes
- Automatic service restart on failure
- Resource usage monitoring
- Log rotation and cleanup

### External Monitoring (Optional)
- CloudWatch integration
- Datadog agent
- New Relic monitoring
- Custom alerting via email/SMS

## Support and Maintenance

### Regular Maintenance Tasks
- Update system packages monthly
- Rotate SSL certificates (automatic)
- Monitor disk space and logs
- Review security logs
- Update Node.js and dependencies as needed

### Emergency Procedures
- Application not responding: `sudo systemctl restart itservicedesk`
- Database connection lost: Check RDS status and security groups
- High load: Monitor with `htop` and restart if needed
- SSL issues: Check certificate expiry and renew if needed