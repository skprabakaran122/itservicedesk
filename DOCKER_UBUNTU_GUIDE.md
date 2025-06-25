# Docker on Ubuntu Production Deployment Guide

Complete guide for deploying the IT Service Desk application using Docker on Ubuntu with AWS RDS.

## Quick Start

### 1. Automated Deployment
```bash
# Run the complete deployment script
chmod +x deploy-docker-ubuntu.sh
./deploy-docker-ubuntu.sh
```

### 2. Configure RDS Connection
```bash
# Edit the production environment file
sudo nano /opt/itservicedesk/.env.prod

# Update RDS configuration:
DATABASE_URL=postgresql://username:password@your-rds-endpoint.region.rds.amazonaws.com:5432/itservicedesk?sslmode=require
DB_HOST=your-rds-endpoint.region.rds.amazonaws.com
DB_USER=your_db_username
DB_PASSWORD=your_db_password
```

### 3. Start Application
```bash
# Start the application
sudo systemctl start itservicedesk

# Check status
/opt/itservicedesk/monitor.sh
```

### 4. Setup SSL (Optional)
```bash
# Configure SSL with Let's Encrypt
chmod +x ubuntu-docker-ssl.sh
./ubuntu-docker-ssl.sh yourdomain.com admin@yourdomain.com
```

## What Gets Installed

### System Components
- **Docker CE**: Latest Docker Community Edition
- **Docker Compose**: Container orchestration
- **Nginx**: Reverse proxy and SSL termination
- **UFW Firewall**: Security configuration
- **Fail2ban**: SSH brute force protection
- **Certbot**: Let's Encrypt SSL certificates

### Application Setup
- **Containerized App**: IT Service Desk in Docker container
- **RDS Integration**: AWS PostgreSQL database connection
- **File Storage**: Persistent uploads and logs
- **Health Monitoring**: Automated health checks
- **Log Rotation**: Automated log management

## Management Commands

### Application Management
```bash
# Located in /opt/itservicedesk/

# Start application
./manage.sh start

# Stop application
./manage.sh stop

# Restart application
./manage.sh restart

# Rebuild and restart (after code changes)
./manage.sh rebuild

# View logs
./manage.sh logs

# Check status
./manage.sh status

# Access container shell
./manage.sh shell

# Run database migrations
./manage.sh migrate

# Create database backup
./manage.sh backup
```

### System Services
```bash
# Application service
sudo systemctl {start|stop|restart|status} itservicedesk

# Nginx
sudo systemctl {start|stop|restart|status} nginx

# Docker
sudo systemctl {start|stop|restart|status} docker

# Check all services
sudo systemctl status itservicedesk nginx docker fail2ban
```

### Monitoring
```bash
# Status dashboard
/opt/itservicedesk/monitor.sh

# Docker stats
docker stats

# Container logs
docker logs itservice_app_ubuntu

# System resources
htop
df -h
free -h
```

## Configuration Files

### Docker Compose
- **File**: `/opt/itservicedesk/docker-compose.ubuntu.yml`
- **Purpose**: Container orchestration and configuration
- **Features**: Resource limits, health checks, volume mounts

### Environment
- **File**: `/opt/itservicedesk/.env.prod`
- **Purpose**: Production environment variables
- **Contains**: RDS connection, app settings, security keys

### Nginx
- **File**: `/etc/nginx/sites-available/itservicedesk`
- **Purpose**: Reverse proxy configuration
- **Features**: SSL termination, security headers, static file serving

### Systemd Service
- **File**: `/etc/systemd/system/itservicedesk.service`
- **Purpose**: Automatic startup and service management
- **Features**: Docker Compose integration, restart policies

## Security Configuration

### Firewall (UFW)
```bash
# Check firewall status
sudo ufw status

# Allow specific ports
sudo ufw allow 22    # SSH
sudo ufw allow 80    # HTTP
sudo ufw allow 443   # HTTPS
```

### Fail2ban
```bash
# Check protection status
sudo fail2ban-client status

# Check SSH jail
sudo fail2ban-client status sshd

# Unban IP (if needed)
sudo fail2ban-client set sshd unbanip IP_ADDRESS
```

### SSL Certificates
```bash
# Check certificate status
sudo certbot certificates

# Manual renewal
sudo certbot renew

# Test automatic renewal
sudo certbot renew --dry-run
```

## Database Operations

### Migrations
```bash
# Run migrations via container
/opt/itservicedesk/manage.sh migrate

# Manual migration
docker exec itservice_app_ubuntu node migrations/run_migrations.cjs
```

### Database Access
```bash
# Connect to RDS from container
/opt/itservicedesk/manage.sh shell
psql $DATABASE_URL

# Direct connection to RDS
psql -h your-rds-endpoint.region.rds.amazonaws.com -U username -d itservicedesk
```

### Backup and Restore
```bash
# Create backup
/opt/itservicedesk/manage.sh backup

# Manual backup
pg_dump $DATABASE_URL > backup-$(date +%Y%m%d).sql

# Restore backup
psql $DATABASE_URL < backup-file.sql
```

## Performance Optimization

### Container Resources
```yaml
# In docker-compose.ubuntu.yml
deploy:
  resources:
    limits:
      memory: 1G      # Adjust based on server capacity
      cpus: '0.5'     # Adjust based on server capacity
    reservations:
      memory: 512M
      cpus: '0.25'
```

### Nginx Optimization
```nginx
# Add to nginx configuration
worker_processes auto;
worker_connections 1024;

# Enable gzip compression
gzip on;
gzip_types text/plain application/json application/javascript text/css;

# Enable caching
location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}
```

### Docker Optimization
```bash
# Clean up unused Docker resources
docker system prune -f

# Remove unused images
docker image prune -f

# Monitor container performance
docker stats --no-stream
```

## Troubleshooting

### Container Issues
```bash
# Check container status
docker ps -a

# View container logs
docker logs itservice_app_ubuntu

# Restart container
./manage.sh restart

# Rebuild container
./manage.sh rebuild
```

### Database Connection Issues
```bash
# Test RDS connectivity from container
/opt/itservicedesk/manage.sh shell
node -e "require('dotenv').config(); const {Pool} = require('pg'); const pool = new Pool({connectionString: process.env.DATABASE_URL}); pool.query('SELECT 1').then(() => console.log('Connected')).catch(console.error);"

# Check environment variables
cat /opt/itservicedesk/.env.prod
```

### SSL Issues
```bash
# Check certificate
sudo certbot certificates

# Test SSL configuration
sudo nginx -t

# Check certificate expiry
openssl x509 -in /etc/letsencrypt/live/yourdomain.com/cert.pem -text -noout | grep "Not After"
```

### Performance Issues
```bash
# Check system resources
htop
free -h
df -h

# Check container stats
docker stats

# Monitor application logs
./manage.sh logs

# Check nginx access logs
sudo tail -f /var/log/nginx/access.log
```

## Backup and Recovery

### Automated Backups
The system includes automated backups:
- **Application**: Daily tar.gz of application files
- **Database**: Daily SQL dump (via manage.sh backup)
- **Logs**: Rotated daily, kept for 52 weeks

### Manual Backup
```bash
# Full system backup
tar -czf itservice-full-backup-$(date +%Y%m%d).tar.gz \
  /opt/itservicedesk \
  /etc/nginx/sites-available/itservicedesk \
  /etc/systemd/system/itservicedesk.service

# Database backup
/opt/itservicedesk/manage.sh backup
```

### Recovery Procedures
```bash
# Restore application
sudo systemctl stop itservicedesk
sudo tar -xzf itservice-full-backup-*.tar.gz -C /
sudo systemctl start itservicedesk

# Restore database
psql $DATABASE_URL < backup-file.sql
```

## Monitoring and Alerts

### Built-in Monitoring
- Container health checks every 30 seconds
- Automatic restart on failure
- Resource usage monitoring
- Log rotation and cleanup

### Log Locations
- **Application**: `/opt/itservicedesk/logs/`
- **Container**: `docker logs itservice_app_ubuntu`
- **Nginx**: `/var/log/nginx/`
- **System**: `/var/log/syslog`

### Health Endpoints
- **Application**: `http://localhost/health`
- **Container**: `http://127.0.0.1:5000/health`

## Scaling and Load Balancing

### Horizontal Scaling
```yaml
# Update docker-compose.ubuntu.yml for multiple instances
version: '3.8'
services:
  app1:
    # ... container config
    ports:
      - "127.0.0.1:5001:5000"
  app2:
    # ... container config
    ports:
      - "127.0.0.1:5002:5000"
```

### Load Balancer Configuration
```nginx
# Add to nginx configuration
upstream app_servers {
    server 127.0.0.1:5001;
    server 127.0.0.1:5002;
}

server {
    location / {
        proxy_pass http://app_servers;
        # ... other proxy settings
    }
}
```

## Maintenance

### Regular Tasks
- Update system packages monthly
- Monitor disk space and logs
- Review security logs
- Update Docker images as needed
- Check SSL certificate renewal

### Update Procedures
```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Update Docker images
./manage.sh rebuild

# Update SSL certificates (automatic)
sudo certbot renew
```

### Emergency Procedures
- **Application Down**: `sudo systemctl restart itservicedesk`
- **High Load**: Check with `docker stats` and `htop`
- **Disk Full**: Clean logs and Docker images
- **SSL Expired**: `sudo certbot renew --force-renewal`

This guide covers all aspects of running the IT Service Desk application in Docker on Ubuntu with AWS RDS integration.