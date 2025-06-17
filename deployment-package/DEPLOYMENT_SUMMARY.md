# IT Service Desk - Complete Deployment Package

## Package Contents

### Application Files
- `client/` - React frontend application
- `server/` - Express backend with TypeScript
- `shared/` - Shared schemas and types
- `package.json` - Dependencies and build scripts
- Configuration files (Vite, Tailwind, Drizzle, etc.)

### Deployment Scripts
- `deploy_to_server.sh` - Complete automated deployment
- `clean_and_deploy.sh` - Clean installation (removes existing)
- `fix_deployment_issues.sh` - Fixes common deployment problems
- `debug_application_startup.sh` - Diagnoses application startup issues

### Documentation
- `DEPLOYMENT_INSTRUCTIONS.txt` - Quick start guide
- `TROUBLESHOOTING.md` - Comprehensive problem-solving guide
- `DEPLOYMENT_SUMMARY.md` - This overview

## Deployment Process

### Step 1: Upload Package
Upload the entire `deployment-package` folder to your Ubuntu server:
```bash
scp -r deployment-package user@server-ip:~/
```

### Step 2: Run Deployment
```bash
ssh user@server-ip
cd deployment-package
./deploy_to_server.sh
```

### Step 3: Fix Common Issues (if needed)
If deployment encounters problems:
```bash
./fix_deployment_issues.sh
```

### Step 4: Debug Application (if not responding)
If application doesn't start properly:
```bash
./debug_application_startup.sh
```

## What Gets Installed

### System Components
- Node.js 20 with npm
- PostgreSQL database server
- Nginx web server
- PM2 process manager
- UFW firewall

### Application Setup
- Database: `servicedesk` with user `servicedesk`
- Application runs on port 3000
- Nginx proxies port 80/443 to application
- SSL certificates (self-signed, upgradeable to Let's Encrypt)
- Process management with auto-restart

### Security Features
- Firewall configured (ports 22, 80, 443 only)
- SSL encryption
- Security headers in Nginx
- Database access restricted to localhost

## Post-Deployment

### Access Your Application
- HTTP: `http://your-server-ip`
- HTTPS: `https://your-server-ip`

### Default Credentials
- Username: `admin`
- Password: `admin` (change immediately)

### Management Commands
```bash
pm2 status              # Check application status
pm2 logs servicedesk    # View application logs
pm2 restart servicedesk # Restart application
./update.sh             # Update application
./backup.sh             # Backup database
```

### Configuration Locations
- Application: `/var/www/servicedesk`
- Logs: `/var/log/servicedesk/`
- Nginx config: `/etc/nginx/sites-available/servicedesk`
- Database: PostgreSQL on localhost:5432

## Troubleshooting Quick Reference

### Application Not Starting
1. Run: `./debug_application_startup.sh`
2. Check: `pm2 logs servicedesk`
3. Verify: `tsx server/index.ts` (manual start)

### Nginx Issues
1. Test: `sudo nginx -t`
2. Restart: `sudo systemctl restart nginx`
3. Check: `sudo systemctl status nginx`

### Database Problems
1. Test: `psql -U servicedesk -d servicedesk -h localhost`
2. Reset: Follow database reset procedure in troubleshooting guide

### Complete Reset
If all else fails: `./clean_and_deploy.sh`

## Success Indicators

- PM2 shows "online" status
- `curl http://localhost:3000` returns HTML
- Web interface accessible via browser
- No errors in PM2 logs
- Database connection working

## Support

All scripts include comprehensive error checking and status reporting. The troubleshooting guide covers the most common deployment scenarios and their solutions.

Your IT Service Desk includes:
- Complete ticketing system
- Change management
- User administration
- Email notifications (SendGrid)
- Role-based access control
- File attachments
- SLA tracking
- Professional Calpion branding