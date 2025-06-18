# Production Deployment Guide

## Quick Deploy to Ubuntu Server

Run this single command on your Ubuntu server:

```bash
curl -sSL https://raw.githubusercontent.com/skprabakaran122/itservicedesk/main/deploy.sh | sudo bash
```

## What Gets Deployed

- **Frontend**: Production React build with Calpion branding
- **Backend**: Express.js server with all API endpoints
- **Database**: Connects to your existing PostgreSQL
- **Security**: HTTPS with SSL certificates
- **Process Manager**: PM2 for reliable service management
- **Reverse Proxy**: Nginx for external access

## Access Your Application

After deployment:
- **URL**: https://[your-server-ip]
- **Login**: john.doe / password123

## Management Commands

```bash
# View application logs
pm2 logs itservicedesk

# Restart application
pm2 restart itservicedesk

# Check status
pm2 status

# View nginx logs
sudo tail -f /var/log/nginx/access.log
```

## Features Available

- Ticket management with SLA tracking
- Change request workflows
- User management with role-based access
- Product catalog management
- Email notifications (configure SendGrid in settings)
- File attachments and document management
- Approval workflows with email-based approvals
- Dashboard with metrics and reporting

## System Requirements

- Ubuntu 18.04+ server
- 2GB+ RAM recommended
- Open ports 80 and 443 for web traffic
- PostgreSQL database (will connect to existing)

The deployment script handles all dependencies, SSL certificates, firewall configuration, and service setup automatically.