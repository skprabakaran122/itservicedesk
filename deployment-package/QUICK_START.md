# IT Service Desk - Quick Start Deployment

## One-Command Deployment

Upload this package to your Ubuntu server and run:

```bash
cd deployment-package
./deploy_to_server.sh
```

## If Deployment Fails

Most common issues and fixes:

### 1. Application Shows "Online" but Not Responding
```bash
./fix_es_modules_env.sh
```

### 2. PM2 Configuration Errors
```bash
./fix_deployment_issues.sh
```

### 3. Complete Clean Installation
```bash
./clean_and_deploy.sh
```

### 4. Debug Application Startup
```bash
./debug_application_startup.sh
```

## Access Your Application

After successful deployment:
- **URL:** http://your-server-ip
- **Admin Login:** admin / admin (change immediately)
- **HTTPS:** Available with self-signed certificate

## Management Commands

```bash
pm2 status              # Check application status
pm2 logs servicedesk    # View logs
pm2 restart servicedesk # Restart application
sudo systemctl status nginx # Check web server
```

## Success Indicators

- PM2 shows "online" status
- `curl http://localhost:3000` returns HTML
- Web interface loads in browser
- No errors in PM2 logs

## Support

All scripts include error checking and detailed logs. Check TROUBLESHOOTING.md for comprehensive problem-solving guidance.