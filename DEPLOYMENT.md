# Calpion IT Service Desk - Production Deployment Guide

## Essential Files Overview

### Core Application Files
- **server.js** - Production-ready Node.js server with Ubuntu compatibility
- **ecosystem.config.cjs** - PM2 production configuration (CommonJS format)
- **ecosystem.dev.config.cjs** - PM2 development configuration

### Deployment Scripts
- **deploy.sh** - Standard production deployment with nginx and HTTPS
- **deploy-ubuntu-compatible.sh** - Ubuntu-specific deployment with trust authentication
- **deploy-production-pm2.sh** - Complete PM2 production setup
- **clean-build.sh** - Minimal deployment with 3-file structure

### Development Tools
- **dev-pm2.sh** - Development PM2 management (start/stop/restart/logs/status)
- **init-dev-environment.sh** - Development database setup
- **fix-email-sendgrid.sh** - Email configuration diagnostics

## Quick Deployment Commands

### For Ubuntu Server (Recommended)
```bash
cd /var/www/itservicedesk
sudo bash deploy-ubuntu-compatible.sh
```

### For Clean Minimal Deployment
```bash
cd /var/www/itservicedesk
sudo bash clean-build.sh
```

### For Full Production Setup
```bash
cd /var/www/itservicedesk
sudo bash deploy-production-pm2.sh
```

## Development Workflow

### PM2 Development Commands
```bash
./dev-pm2.sh start      # Start development server with PM2
./dev-pm2.sh stop       # Stop development server
./dev-pm2.sh restart    # Restart development server
./dev-pm2.sh logs       # View development logs
./dev-pm2.sh status     # Check server status
./dev-pm2.sh health     # Health check
./dev-pm2.sh test-auth  # Test authentication
```

### Database Setup
```bash
./init-dev-environment.sh  # Setup development database
```

## Email Configuration

### SendGrid Setup
1. Update API key in admin console or via API
2. Whitelist server IP address in SendGrid account
3. Test email functionality

### IP Whitelisting
- Development IP: Check with `./fix-email-sendgrid.sh`
- Production IP: Whitelist your Ubuntu server IP

## Application Access

### Production URLs
- **Application**: http://your-server-ip
- **Health Check**: http://your-server-ip/api/health

### Default Accounts
- **admin/password123** - System Administrator
- **support/password123** - Support Technician
- **manager/password123** - IT Manager
- **test.user/password123** - Test User

## System Requirements

### Ubuntu Server
- Node.js 20.x
- PostgreSQL 12+
- Nginx (for reverse proxy)
- PM2 (process manager)

### Database Configuration
- PostgreSQL with trust authentication
- Database name: servicedesk
- User: postgres
- No password required (trust authentication)

## Monitoring and Maintenance

### PM2 Commands
```bash
pm2 status                    # Check application status
pm2 logs servicedesk          # View application logs
pm2 restart servicedesk       # Restart application
pm2 stop servicedesk          # Stop application
pm2 start ecosystem.config.cjs # Start from configuration
```

### Health Checks
```bash
curl http://localhost:5000/api/health
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"password123"}'
```

## Troubleshooting

### Common Issues
1. **PM2 Module Errors**: Use .cjs configuration files
2. **Database Connection**: Ensure trust authentication enabled
3. **Email Failures**: Check IP whitelisting in SendGrid
4. **Port Conflicts**: Application runs on port 5000

### Log Locations
- **PM2 Logs**: ./logs/ directory
- **Application Logs**: Console output via PM2
- **Nginx Logs**: /var/log/nginx/

## Security Considerations

### Production Checklist
- [ ] Change default passwords
- [ ] Configure SSL certificates
- [ ] Enable firewall (ports 22, 80, 443)
- [ ] Update SendGrid IP whitelist
- [ ] Configure backup procedures
- [ ] Enable PM2 startup script

### Network Configuration
- **HTTP**: Port 80 (nginx proxy)
- **HTTPS**: Port 443 (SSL termination)
- **Application**: Port 5000 (internal)
- **SSH**: Port 22 (server access)

## Support

For deployment issues:
1. Check application health endpoint
2. Review PM2 logs
3. Verify database connectivity
4. Test authentication endpoints
5. Confirm email configuration

All deployment scripts include comprehensive error checking and status reporting.