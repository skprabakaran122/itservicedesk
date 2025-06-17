# HTTPS Deployment Guide for Calpion IT Service Desk

## Overview

Your server now supports HTTPS with automatic HTTP to HTTPS redirection, security headers, and flexible certificate management.

## Quick Start

### Development (Self-Signed Certificate)

1. **Generate self-signed certificate:**
   ```bash
   chmod +x setup-https.sh
   ./setup-https.sh
   # Choose option 1 for self-signed certificate
   ```

2. **Start the server:**
   ```bash
   npm run dev
   ```

3. **Access the application:**
   - HTTPS: https://localhost:5001
   - HTTP: http://localhost:5000 (automatically redirects to HTTPS)

### Production (Let's Encrypt)

1. **Setup Let's Encrypt certificate:**
   ```bash
   ./setup-https.sh
   # Choose option 2 and provide your domain and email
   ```

2. **Configure firewall:**
   ```bash
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   sudo ufw allow 5000/tcp
   sudo ufw allow 5001/tcp
   ```

## Certificate Management Options

### Option 1: Environment Variables
Set SSL certificates via environment variables:
```bash
export SSL_CERT="-----BEGIN CERTIFICATE-----
...certificate content...
-----END CERTIFICATE-----"

export SSL_KEY="-----BEGIN PRIVATE KEY-----
...private key content...
-----END PRIVATE KEY-----"
```

### Option 2: File System
Place certificate files in the `./ssl/` directory:
- `./ssl/cert.pem` - SSL certificate
- `./ssl/key.pem` - Private key

### Option 3: Let's Encrypt (Automatic)
The server automatically checks for Let's Encrypt certificates at:
- `/etc/letsencrypt/live/domain/fullchain.pem`
- `/etc/letsencrypt/live/domain/privkey.pem`

## Security Features

### HTTPS Security Headers
- `Strict-Transport-Security`: Forces HTTPS for 1 year
- `X-Content-Type-Options`: Prevents MIME sniffing
- `X-Frame-Options`: Prevents clickjacking
- `X-XSS-Protection`: XSS protection
- `Referrer-Policy`: Controls referrer information

### Automatic HTTP to HTTPS Redirect
- HTTP requests on port 5000 automatically redirect to HTTPS on port 5001
- Production environments force HTTPS for all requests

## Production Deployment

### 1. Server Setup
```bash
# Install required packages
sudo apt update
sudo apt install -y nginx certbot python3-certbot-nginx

# Clone and setup project
git clone <your-repo>
cd calpion-service-desk
npm install
```

### 2. SSL Certificate
```bash
# Generate Let's Encrypt certificate
sudo certbot --nginx -d your-domain.com

# Or run our setup script
./setup-https.sh
```

### 3. Nginx Configuration (Optional)
Create `/etc/nginx/sites-available/calpion-service-desk`:
```nginx
server {
    listen 80;
    server_name your-domain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name your-domain.com;

    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;

    location / {
        proxy_pass https://localhost:5001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

### 4. PM2 Configuration
Update `ecosystem.config.cjs` for production:
```javascript
module.exports = {
  apps: [{
    name: 'calpion-service-desk',
    script: 'server/index.ts',
    interpreter: 'tsx',
    env: {
      NODE_ENV: 'production',
      SSL_CERT_PATH: '/etc/letsencrypt/live/your-domain.com/fullchain.pem',
      SSL_KEY_PATH: '/etc/letsencrypt/live/your-domain.com/privkey.pem'
    }
  }]
};
```

## Troubleshooting

### Certificate Issues
```bash
# Check certificate validity
openssl x509 -in ssl/cert.pem -text -noout

# Verify certificate and key match
openssl x509 -noout -modulus -in ssl/cert.pem | openssl md5
openssl rsa -noout -modulus -in ssl/key.pem | openssl md5
```

### Port Issues
```bash
# Check port availability
sudo netstat -tlnp | grep :5001
sudo netstat -tlnp | grep :5000

# Kill processes using ports
sudo fuser -k 5001/tcp
sudo fuser -k 5000/tcp
```

### Firewall Configuration
```bash
# Ubuntu/Debian
sudo ufw status
sudo ufw allow 80
sudo ufw allow 443
sudo ufw allow 5000
sudo ufw allow 5001

# CentOS/RHEL
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --permanent --add-port=5000/tcp
sudo firewall-cmd --permanent --add-port=5001/tcp
sudo firewall-cmd --reload
```

## Monitoring and Maintenance

### Certificate Renewal
Let's Encrypt certificates auto-renew via crontab:
```bash
# Check current cron jobs
crontab -l

# Manual renewal test
sudo certbot renew --dry-run
```

### Log Monitoring
```bash
# Server logs
pm2 logs calpion-service-desk

# Nginx logs (if using)
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

## Testing HTTPS

### Browser Testing
1. Navigate to your domain
2. Check for green lock icon
3. Verify certificate details
4. Test HTTP to HTTPS redirect

### Command Line Testing
```bash
# Test HTTP redirect
curl -I http://your-domain.com

# Test HTTPS
curl -I https://your-domain.com

# Test SSL certificate
openssl s_client -connect your-domain.com:443 -servername your-domain.com
```

## Security Considerations

1. **Certificate Management**: Keep private keys secure and never commit them to version control
2. **Regular Updates**: Keep SSL certificates current and monitor expiration
3. **Security Headers**: All security headers are automatically applied
4. **Access Control**: Limit server access to necessary ports only
5. **Backup**: Maintain backups of SSL certificates and configuration

## Support

For additional assistance with HTTPS deployment:
1. Check server logs for SSL-related errors
2. Verify DNS configuration points to your server
3. Ensure firewall rules allow HTTPS traffic
4. Contact your hosting provider for infrastructure support