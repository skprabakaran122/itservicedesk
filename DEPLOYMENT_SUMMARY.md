# Complete Clean Deployment Summary

## What clean-and-deploy.sh Does

### 1. Complete Software Removal
- **Node.js & npm**: Removes all versions and related packages
- **PostgreSQL**: Completely removes database server, data, and users
- **Nginx**: Removes web server and all configurations
- **PM2**: Uninstalls process manager globally
- **Build Tools**: Removes development dependencies

### 2. Deep Configuration Cleanup
- Removes all configuration files from `/etc/`
- Deletes SSL certificates and keys
- Cleans systemd services
- Removes log files
- Clears package caches
- Eliminates user-specific configurations

### 3. Fresh Installation
- Installs latest Node.js 20
- Sets up PostgreSQL with new database
- Configures Nginx with HTTPS
- Generates new SSL certificates
- Sets up PM2 process manager

## Quick Usage

```bash
# Make scripts executable
chmod +x check-system.sh clean-and-deploy.sh

# Check current system state (optional)
./check-system.sh

# Clean and deploy
sudo ./clean-and-deploy.sh
```

## What Gets Installed Fresh

### Software Stack
- **Node.js 20** (latest LTS)
- **PostgreSQL** (latest stable)
- **Nginx** (latest stable)
- **PM2** (process manager)

### Database Setup
- Database: `servicedesk`
- User: `servicedesk`
- Password: `servicedesk123`

### SSL Configuration
- Self-signed certificate (365 days)
- Modern TLS protocols (1.2, 1.3)
- Security headers
- HTTPS redirect

### Application Setup
- Production build
- Environment configuration
- Process monitoring
- Auto-restart capability

## File Structure After Deployment

```
/etc/nginx/
├── ssl/
│   ├── servicedesk.crt
│   └── servicedesk.key
└── sites-available/
    └── servicedesk

/var/log/
├── nginx/
└── postgresql/

~/ (application directory)
├── dist/           # Built application
├── logs/           # Application logs
├── .env            # Environment variables
└── ecosystem.config.js  # PM2 configuration
```

## Services and Ports

| Service | Port | Purpose |
|---------|------|---------|
| Application | 3000 | Node.js server |
| HTTP | 80 | Redirects to HTTPS |
| HTTPS | 443 | Secure web access |
| PostgreSQL | 5432 | Database |

## Post-Deployment Access

- **Main URL**: https://your-server-ip
- **Default Login**: john.doe / password123
- **Database**: localhost:5432/servicedesk

## Management Commands

```bash
# Application
pm2 status
pm2 logs servicedesk
pm2 restart servicedesk

# Web Server
sudo systemctl status nginx
sudo nginx -t

# Database
sudo systemctl status postgresql
psql -h localhost -U servicedesk -d servicedesk

# SSL Certificate
openssl x509 -in /etc/nginx/ssl/servicedesk.crt -text -noout
```

## Security Features

- HTTPS with modern TLS
- Security headers (HSTS, XSS protection)
- Firewall configuration
- Process isolation
- Database user privileges

## What Gets Preserved

- System users and groups (except postgres)
- SSH configuration
- System firewall rules
- Non-related software and configurations

## Troubleshooting

If deployment fails, check:
1. Internet connectivity
2. Sudo permissions
3. Available disk space
4. Port availability

The script includes verification steps and will report any issues during installation.