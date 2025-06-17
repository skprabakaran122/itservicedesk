# IT Service Desk - Deployment Troubleshooting Guide

## Common Issues and Solutions

### 1. Application Not Responding on Port 3000

**Symptoms:**
- PM2 shows application as "online" but curl fails
- Empty PM2 logs
- Nginx configuration is correct

**Solutions:**

#### Check tsx Installation
```bash
which tsx
npm list -g tsx
sudo npm install -g tsx
```

#### Verify Dependencies
```bash
cd /var/www/servicedesk
npm install
npm run build
```

#### Test Manual Startup
```bash
cd /var/www/servicedesk
tsx server/index.ts
# Look for error messages
```

#### Check Environment Variables
```bash
cat .env
# Ensure DATABASE_URL is correct
```

### 2. PM2 Configuration Errors

**Error:** `module is not defined`

**Solution:** Use `.cjs` extension for CommonJS format
```bash
mv ecosystem.config.js ecosystem.config.cjs
```

### 3. Database Connection Issues

**Symptoms:**
- Application fails to start
- Database permission errors

**Solutions:**

#### Reset Database Permissions
```bash
sudo -u postgres psql << 'EOF'
DROP DATABASE IF EXISTS servicedesk;
DROP USER IF EXISTS servicedesk;
CREATE USER servicedesk WITH PASSWORD 'your_password' SUPERUSER;
CREATE DATABASE servicedesk OWNER servicedesk;
\q
EOF
```

#### Test Database Connection
```bash
psql -U servicedesk -d servicedesk -h localhost
```

### 4. Nginx Configuration Issues

**Error:** `nginx: configuration file test is successful` but server not accessible

**Solutions:**

#### Check Nginx Status
```bash
sudo systemctl status nginx
sudo nginx -t
```

#### Verify Site Configuration
```bash
sudo ln -sf /etc/nginx/sites-available/servicedesk /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo systemctl restart nginx
```

### 5. Firewall Blocking Access

**Symptoms:**
- Application works locally but not externally
- Connection timeouts

**Solutions:**

#### Configure UFW
```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw status
```

#### Check iptables
```bash
sudo iptables -L
```

## Quick Diagnostic Commands

```bash
# Check all services
sudo systemctl status nginx postgresql
pm2 status

# Check ports
sudo netstat -tulpn | grep -E ':(80|443|3000|5432)'

# Check logs
pm2 logs servicedesk
sudo tail -f /var/log/nginx/error.log
journalctl -u nginx -f

# Test connectivity
curl http://localhost:3000
curl http://localhost
```

## Complete Reset Procedure

If all else fails, use the clean deployment:

```bash
./clean_and_deploy.sh
```

This removes all existing installations and starts fresh.

## Manual Application Start (for debugging)

```bash
cd /var/www/servicedesk
export NODE_ENV=production
export PORT=3000
tsx server/index.ts
```

Watch for error messages that indicate the specific problem.

## Environment File Template

```bash
cat > .env << 'EOF'
DATABASE_URL=postgresql://servicedesk:your_password@localhost:5432/servicedesk
NODE_ENV=production
PORT=3000
SENDGRID_API_KEY=your_api_key_here
EOF
```

## Successful Deployment Indicators

- PM2 status shows "online"
- `curl http://localhost:3000` returns HTML
- `curl http://localhost` returns HTML (through Nginx)
- No errors in PM2 logs
- Nginx test passes
- Database connection works

## Getting Help

1. Run diagnostic script: `./debug_application_startup.sh`
2. Check all logs mentioned above
3. Verify each component individually
4. Use clean deployment if configuration is corrupted