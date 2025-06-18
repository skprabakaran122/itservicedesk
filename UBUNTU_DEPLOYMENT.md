# Ubuntu Deployment Guide - IT Service Desk

This guide walks you through deploying the IT Service Desk on Ubuntu 20.04/22.04 with Nginx reverse proxy and HTTPS using self-signed certificates.

## Prerequisites

- Ubuntu 20.04 or 22.04 server
- Root or sudo access
- Git installed
- Internet connection

## Quick Deployment

### 1. Clone Repository

```bash
git clone <your-git-repository-url>
cd <repository-name>
```

### 2. Run Deployment Script

```bash
chmod +x deploy.sh
sudo ./deploy.sh
```

The script will automatically:
- Install Node.js 20, PostgreSQL, and Nginx
- Create database and user
- Install dependencies and build application
- Generate self-signed SSL certificate
- Configure Nginx with HTTPS
- Set up PM2 process manager
- Configure firewall

### 3. Access Application

- **HTTPS**: https://your-server-ip
- **HTTP**: http://your-server-ip (redirects to HTTPS)

**Note**: Browsers will show a security warning for self-signed certificates. Click "Advanced" and "Proceed" to continue.

## Manual Deployment Steps

If you prefer manual installation:

### 1. Install Dependencies

```bash
# Update system
sudo apt update -y

# Install Node.js 20
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Install other dependencies
sudo apt install -y postgresql postgresql-contrib nginx

# Install PM2 globally
sudo npm install -g pm2
```

### 2. Database Setup

```bash
# Start PostgreSQL
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Create database and user
sudo -u postgres psql
```

In PostgreSQL shell:
```sql
CREATE USER servicedesk WITH PASSWORD 'servicedesk123';
CREATE DATABASE servicedesk OWNER servicedesk;
GRANT ALL PRIVILEGES ON DATABASE servicedesk TO servicedesk;
\q
```

### 3. Application Setup

```bash
# Install dependencies
npm install --production

# Create environment file
cat > .env << EOF
DATABASE_URL=postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk
NODE_ENV=production
PORT=3000
SENDGRID_API_KEY=your_sendgrid_key_here
EOF

# Build application
npm run build

# Push database schema
npm run db:push
```

### 4. SSL Certificate

```bash
# Create SSL directory
sudo mkdir -p /etc/nginx/ssl

# Generate self-signed certificate
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/servicedesk.key \
    -out /etc/nginx/ssl/servicedesk.crt \
    -subj "/C=US/ST=State/L=City/O=Calpion/OU=IT/CN=your-server-ip"
```

### 5. Nginx Configuration

Create `/etc/nginx/sites-available/servicedesk`:

```nginx
# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name your-server-ip;
    return 301 https://$server_name$request_uri;
}

# HTTPS server
server {
    listen 443 ssl http2;
    server_name your-server-ip;

    # SSL Configuration
    ssl_certificate /etc/nginx/ssl/servicedesk.crt;
    ssl_certificate_key /etc/nginx/ssl/servicedesk.key;
    
    # SSL Security Settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_timeout 10m;
    ssl_session_cache shared:SSL:10m;
    
    # Security Headers
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;

    # Application Proxy
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_cache_bypass $http_upgrade;
        proxy_redirect off;
    }

    client_max_body_size 10M;
}
```

Enable site:
```bash
sudo ln -s /etc/nginx/sites-available/servicedesk /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

### 6. PM2 Process Manager

Create `ecosystem.config.js`:

```javascript
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'npm',
    args: 'start',
    cwd: process.cwd(),
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production',
      PORT: 3000,
      DATABASE_URL: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk'
    },
    error_file: './logs/error.log',
    out_file: './logs/out.log',
    log_file: './logs/combined.log',
    time: true
  }]
};
```

Start application:
```bash
mkdir -p logs
pm2 start ecosystem.config.js
pm2 save
pm2 startup
```

### 7. Firewall Configuration

```bash
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'
sudo ufw allow 443/tcp
sudo ufw allow 80/tcp
sudo ufw --force enable
```

## Management Commands

### Application Management
```bash
# Check application status
pm2 status

# View logs
pm2 logs servicedesk

# Restart application
pm2 restart servicedesk

# Stop application
pm2 stop servicedesk
```

### Code Updates
```bash
# Pull latest changes
git pull

# Rebuild application
npm run build

# Restart application
pm2 restart servicedesk
```

### Database Management
```bash
# Connect to database
psql -h localhost -U servicedesk -d servicedesk

# Push schema changes
npm run db:push

# Check database status
sudo systemctl status postgresql
```

### SSL Certificate Management
```bash
# Check certificate details
openssl x509 -in /etc/nginx/ssl/servicedesk.crt -text -noout

# Check certificate expiration
openssl x509 -in /etc/nginx/ssl/servicedesk.crt -noout -dates

# Regenerate certificate (if needed)
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/servicedesk.key \
    -out /etc/nginx/ssl/servicedesk.crt \
    -subj "/C=US/ST=State/L=City/O=Calpion/OU=IT/CN=your-server-ip"
sudo systemctl restart nginx
```

### Nginx Management
```bash
# Test configuration
sudo nginx -t

# Reload configuration
sudo systemctl reload nginx

# Restart Nginx
sudo systemctl restart nginx

# Check status
sudo systemctl status nginx
```

## Troubleshooting

### Application Not Starting
```bash
# Check PM2 logs
pm2 logs servicedesk

# Check if port is in use
sudo netstat -tlnp | grep :3000

# Check environment variables
pm2 env 0
```

### Database Connection Issues
```bash
# Check PostgreSQL status
sudo systemctl status postgresql

# Test connection
psql -h localhost -U servicedesk -d servicedesk -c "SELECT 1;"

# Check database logs
sudo tail -f /var/log/postgresql/postgresql-*.log
```

### SSL Certificate Issues
```bash
# Test SSL
curl -k -I https://localhost

# Check certificate
openssl s_client -connect localhost:443 -servername localhost

# Verify Nginx SSL config
sudo nginx -t
```

### Firewall Issues
```bash
# Check firewall status
sudo ufw status

# Check open ports
sudo ss -tlnp

# Allow specific port
sudo ufw allow 443/tcp
```

## Production Considerations

### SSL Certificate
- Replace self-signed certificate with proper CA-issued certificate
- Consider using Let's Encrypt for free SSL certificates
- Set up automatic certificate renewal

### Security
- Change default database password
- Configure proper firewall rules
- Set up fail2ban for intrusion prevention
- Regular security updates

### Monitoring
- Set up log rotation
- Configure monitoring alerts
- Regular backup procedures
- Performance monitoring

### Email Configuration
- Configure SendGrid API key in `.env`
- Test email functionality
- Set up proper from/reply addresses

## Default Login

After deployment, use these credentials to log in:
- **Username**: john.doe
- **Password**: password123

**Important**: Change the default password immediately after first login.

## Support

If you encounter issues during deployment:
1. Check the relevant logs (PM2, Nginx, PostgreSQL)
2. Verify all services are running
3. Check firewall and network configuration
4. Ensure all dependencies are properly installed