# IT Service Desk - Clean Deployment Package

## Overview

This package provides a complete clean deployment solution for the IT Service Desk application on Ubuntu servers. It includes comprehensive cleanup tools and a simplified deployment script that addresses all previously identified issues.

## Deployment Options

### Option 1: Deploy from Files (Local Package)
If you have application files locally:
```bash
./simple_deploy.sh
```

### Option 2: Deploy from Git Repository
To clone and deploy directly from Git:
```bash
./git_deploy.sh
```

### Option 3: Complete Cleanup First
If you have existing installations to remove:
```bash
./complete_cleanup.sh
# Then run either simple_deploy.sh or git_deploy.sh
```

### Fixes for Application Issues

If deployment completes but application doesn't respond:
```bash
./immediate_fix.sh
```

If immediate fix doesn't work, try the PM2 environment fix:
```bash
./pm2_env_fix.sh
```

For ES modules environment issues:
```bash
./final_pm2_fix.sh
```

For complete debugging and startup:
```bash
./debug_and_start.sh
```

**Ultimate comprehensive fix (recommended):**
```bash
./ultimate_deployment_fix.sh
```

**Database connection fix (for WebSocket errors):**
```bash
./database_connection_fix.sh
```

**PostgreSQL import fix (for ES modules errors):**
```bash
./pg_import_fix.sh
```

## What Gets Installed

- **Node.js 20** with npm package manager
- **PostgreSQL** database with `servicedesk` user and database
- **Nginx** web server with reverse proxy configuration
- **PM2** process manager for application lifecycle
- **UFW Firewall** configured for web traffic only

## Application Features

- Complete ticketing system with SLA tracking
- Change management with approval workflows
- User administration with role-based access
- Email notifications via SendGrid
- File attachment support
- Professional Calpion branding
- Responsive web interface

## Access Information

After successful deployment:
- **URL**: http://your-server-ip
- **Admin Username**: admin
- **Admin Password**: admin (change immediately)

## File Structure

```
clean_deployment_package/
├── complete_cleanup.sh     # Removes all existing components
├── simple_deploy.sh        # Main deployment script
├── client/                 # React frontend application
├── server/                 # Express backend with TypeScript
├── shared/                 # Shared schemas and types
├── package.json           # Dependencies and scripts
└── configuration files    # Vite, Tailwind, Drizzle, etc.
```

## Key Improvements

This clean deployment addresses previous deployment issues:

1. **Environment Variable Loading**: Fixed ES modules dotenv configuration
2. **Database Connection**: Simplified PostgreSQL setup with reliable credentials
3. **Module Loading Order**: Resolved import sequence issues
4. **PM2 Configuration**: Corrected ecosystem configuration format
5. **Nginx Setup**: Streamlined proxy configuration

## Management Commands

```bash
# Application status
pm2 status
pm2 logs servicedesk

# Restart application
pm2 restart servicedesk

# Database access
psql -U servicedesk -d servicedesk -h localhost

# Web server status
sudo systemctl status nginx
sudo nginx -t

# View logs
sudo tail -f /var/log/servicedesk/combined.log
sudo tail -f /var/log/nginx/access.log
```

## Troubleshooting

### Application Not Starting
1. Check PM2 logs: `pm2 logs servicedesk`
2. Test database: `psql -U servicedesk -d servicedesk -h localhost`
3. Verify environment: `cat /var/www/servicedesk/.env`

### Web Server Issues
1. Test Nginx: `sudo nginx -t`
2. Check status: `sudo systemctl status nginx`
3. Restart: `sudo systemctl restart nginx`

### Complete Reset
If issues persist, run complete cleanup and redeploy:
```bash
./complete_cleanup.sh
./simple_deploy.sh
```

## Security Features

- Firewall configured for minimal attack surface
- Database access restricted to localhost
- Nginx security headers enabled
- PM2 process isolation
- Non-root application execution

## Database Configuration

- **Database**: servicedesk
- **User**: servicedesk
- **Password**: servicedesk123 (change in production)
- **Connection**: postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk

## Next Steps After Deployment

1. Change default admin password
2. Configure SendGrid API key for email notifications
3. Set up SSL certificate (optional: Let's Encrypt)
4. Create departments and user accounts
5. Configure organizational settings

This deployment package provides a reliable, tested solution for running the IT Service Desk in production environments.