# Quick Server Deployment Guide

## Prerequisites
You'll need:
- Your PPK key file
- Server IP address
- Ubuntu server with sudo access

## Deployment Steps

### Option 1: Automated Deployment Script
```bash
./deploy-to-server.sh
```
The script will prompt for:
- Server IP address
- Path to your PPK key file
- Domain name (optional)

### Option 2: Manual Deployment
If you prefer manual control:

1. **Convert PPK to PEM** (if needed):
```bash
# Install putty-tools if not available
sudo apt install putty-tools
puttygen your-key.ppk -O private-openssh -o your-key.pem
chmod 600 your-key.pem
```

2. **Copy files to server**:
```bash
# Create deployment package
tar --exclude=node_modules --exclude=.git --exclude=ssl -czf deploy.tar.gz .

# Copy to server
scp -i your-key.pem deploy.tar.gz ubuntu@YOUR_SERVER_IP:/home/ubuntu/
```

3. **Setup server environment**:
```bash
ssh -i your-key.pem ubuntu@YOUR_SERVER_IP

# Update system and install Node.js
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt update && sudo apt install -y nodejs postgresql-client openssl pm2

# Extract application
mkdir -p servicedesk && cd servicedesk
tar -xzf ../deploy.tar.gz
npm install --production
```

4. **Configure environment**:
```bash
# Create .env file
cat > .env << 'EOF'
NODE_ENV=production
DATABASE_URL="postgresql://neondb_owner:npg_CHFj1dqMYB6V@ep-still-snow-a65c90fl.us-west-2.aws.neon.tech/neondb?sslmode=require"
SENDGRID_API_KEY=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
EOF
chmod 600 .env
```

5. **Setup SSL certificates**:
```bash
# Generate self-signed certificate
mkdir -p ssl
openssl req -x509 -newkey rsa:4096 -keyout ssl/key.pem -out ssl/cert.pem -days 365 -nodes \
    -subj "/C=US/ST=State/L=City/O=Calpion/OU=IT/CN=$(curl -s http://checkip.amazonaws.com)"
```

6. **Configure firewall**:
```bash
sudo ufw enable
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 5000/tcp
sudo ufw allow 5001/tcp
```

7. **Start application**:
```bash
# Push database schema
npm run db:push

# Start with PM2
npm install -g pm2
pm2 start ecosystem.config.cjs
pm2 save
pm2 startup
```

## Access Your Application
- HTTPS: https://YOUR_SERVER_IP:5001
- HTTP: http://YOUR_SERVER_IP:5000 (redirects to HTTPS)

## Post-Deployment Commands
```bash
# Check application status
pm2 status

# View logs
pm2 logs

# Restart application
pm2 restart calpion-service-desk

# Update application
git pull && npm install && pm2 restart calpion-service-desk
```

## Production SSL (Optional)
For production with a domain:
```bash
# Install Certbot
sudo apt install certbot

# Get Let's Encrypt certificate
sudo certbot certonly --standalone -d your-domain.com

# Copy certificates
sudo cp /etc/letsencrypt/live/your-domain.com/fullchain.pem ~/servicedesk/ssl/cert.pem
sudo cp /etc/letsencrypt/live/your-domain.com/privkey.pem ~/servicedesk/ssl/key.pem
sudo chown ubuntu:ubuntu ~/servicedesk/ssl/*.pem

# Restart application
pm2 restart calpion-service-desk
```

Your HTTPS-enabled IT Service Desk will be running with all features:
- Email-based approvals
- Overdue change monitoring
- SLA tracking
- Secure SSL/TLS encryption