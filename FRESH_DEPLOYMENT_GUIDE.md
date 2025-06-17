# Complete Fresh Server Deployment Guide

## Quick Start

1. **Make the script executable:**
   ```bash
   chmod +x complete_deployment.sh
   ```

2. **Run the deployment:**
   ```bash
   ./complete_deployment.sh
   ```

3. **Follow the prompts:**
   - Enter your server IP address
   - Provide path to your SSH key (.pem file)
   - Create a database password

## What the Script Does

### System Setup
- Updates Ubuntu packages
- Installs Node.js 20, npm, PostgreSQL, PM2
- Configures firewall (allows ports 22, 80, 443, 5000, 5001)

### Database Setup
- Creates PostgreSQL database `servicedesk`
- Creates database user `servicedesk_user`
- Configures authentication

### Application Deployment
- Creates `/home/ubuntu/servicedesk` directory
- Extracts and builds the application
- Generates SSL certificates
- Configures environment variables
- Runs database migrations
- Starts application with PM2

## After Deployment

### Access Your Application
- **HTTPS:** `https://YOUR_SERVER_IP:5001`
- **HTTP:** `http://YOUR_SERVER_IP:5000` (redirects to HTTPS)

### Add SendGrid Email (Optional)
```bash
ssh -i your-key.pem ubuntu@YOUR_SERVER_IP
cd /home/ubuntu/servicedesk
nano .env
# Add: SENDGRID_API_KEY=your_actual_key_here
pm2 restart calpion-service-desk
```

### Monitor Application
```bash
# Check status
ssh -i your-key.pem ubuntu@YOUR_SERVER_IP 'pm2 status'

# View logs
ssh -i your-key.pem ubuntu@YOUR_SERVER_IP 'pm2 logs'

# Restart if needed
ssh -i your-key.pem ubuntu@YOUR_SERVER_IP 'pm2 restart calpion-service-desk'
```

### SSL Certificate Notes
- Self-signed certificates are generated automatically
- Valid for 1 year
- Browsers will show security warnings (expected for self-signed)
- For production, consider Let's Encrypt (see optional setup below)

## Optional: Let's Encrypt SSL Setup

For production environments, replace self-signed certificates with Let's Encrypt:

```bash
ssh -i your-key.pem ubuntu@YOUR_SERVER_IP

# Install Certbot
sudo apt install snapd
sudo snap install --classic certbot

# Stop application temporarily
pm2 stop calpion-service-desk

# Get certificate (replace YOUR_DOMAIN with actual domain)
sudo certbot certonly --standalone -d YOUR_DOMAIN

# Copy certificates to application
sudo cp /etc/letsencrypt/live/YOUR_DOMAIN/privkey.pem /home/ubuntu/servicedesk/ssl/key.pem
sudo cp /etc/letsencrypt/live/YOUR_DOMAIN/fullchain.pem /home/ubuntu/servicedesk/ssl/cert.pem
sudo chown ubuntu:ubuntu /home/ubuntu/servicedesk/ssl/*.pem
chmod 600 /home/ubuntu/servicedesk/ssl/key.pem

# Restart application
pm2 start calpion-service-desk
```

## Troubleshooting

### Database Connection Issues
```bash
sudo systemctl status postgresql
sudo -u postgres psql -c "\l"  # List databases
```

### Application Not Starting
```bash
pm2 logs calpion-service-desk
cd /home/ubuntu/servicedesk && npm run db:push
```

### Firewall Issues
```bash
sudo ufw status
sudo ufw allow 5001/tcp
```

### SSL Certificate Issues
```bash
cd /home/ubuntu/servicedesk/ssl
ls -la
openssl x509 -in cert.pem -text -noout
```

Your IT Service Desk will be fully operational with HTTPS security, database persistence, and production-ready configuration.