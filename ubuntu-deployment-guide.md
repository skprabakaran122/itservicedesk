# Ubuntu Server Deployment Guide - IT Service Desk

## Prerequisites
- Ubuntu server (tested on 20.04+)
- Root or sudo access
- Internet connection

## Step 1: Server Preparation

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Node.js 20.x
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install nginx and postgresql
sudo apt install nginx postgresql postgresql-contrib -y

# Install PM2 globally
sudo npm install -g pm2

# Install git
sudo apt install git -y
```

## Step 2: Database Setup

```bash
# Switch to postgres user
sudo -u postgres psql

# Create database and user (run these commands in psql)
CREATE DATABASE servicedesk;
CREATE USER servicedesk WITH PASSWORD 'SecurePass123';
GRANT ALL PRIVILEGES ON DATABASE servicedesk TO servicedesk;
ALTER USER servicedesk CREATEDB;
\q

# Configure PostgreSQL for local connections
sudo nano /etc/postgresql/*/main/pg_hba.conf
# Add this line (replace existing local lines):
local   all             servicedesk                             trust

# Restart PostgreSQL
sudo systemctl restart postgresql
```

## Step 3: Application Deployment

```bash
# Create application directory
sudo mkdir -p /var/www/itservicedesk
cd /var/www/itservicedesk

# Clone the clean repository
sudo git clone https://github.com/skprabakaran122/itservicedesk.git .

# Install dependencies
sudo npm install

# Set permissions
sudo chown -R www-data:www-data /var/www/itservicedesk
sudo chmod -R 755 /var/www/itservicedesk

# Create environment file
sudo tee .env > /dev/null << 'EOF'
NODE_ENV=production
PORT=3000
DATABASE_URL=postgresql://servicedesk:SecurePass123@localhost:5432/servicedesk
SENDGRID_API_KEY=SG.placeholder
EOF

# Create logs directory
sudo mkdir -p logs
sudo chown www-data:www-data logs
```

## Step 4: Start Application with PM2

```bash
# Start the application
sudo -u www-data pm2 start ecosystem.config.cjs

# Save PM2 configuration
sudo -u www-data pm2 save

# Setup PM2 startup script
sudo -u www-data pm2 startup
# Follow the instructions provided by the command above

# Verify application is running
sudo -u www-data pm2 status
```

## Step 5: Nginx Configuration

```bash
# Create nginx configuration
sudo tee /etc/nginx/sites-available/itservicedesk > /dev/null << 'EOF'
server {
    listen 80;
    server_name YOUR_SERVER_IP;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
        proxy_read_timeout 300;
    }
}
EOF

# Enable the site
sudo ln -sf /etc/nginx/sites-available/itservicedesk /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test nginx configuration
sudo nginx -t

# Restart nginx
sudo systemctl restart nginx
```

## Step 6: Firewall Configuration

```bash
# Configure UFW firewall
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'
sudo ufw --force enable
```

## Step 7: Verification

```bash
# Check application status
sudo -u www-data pm2 status

# Check application logs
sudo -u www-data pm2 logs servicedesk --lines 20

# Test health endpoint
curl http://localhost:3000/health

# Test from external
curl http://YOUR_SERVER_IP/health
```

## Login Credentials

Once deployed, access your IT Service Desk at `http://YOUR_SERVER_IP`

**Admin Account:**
- Username: `test.admin`
- Password: `password123`

**User Account:**
- Username: `test.user`
- Password: `password123`

**Agent Account:**
- Username: `john.doe`
- Password: `password123`

## Maintenance Commands

```bash
# View application logs
sudo -u www-data pm2 logs servicedesk

# Restart application
sudo -u www-data pm2 restart servicedesk

# Stop application
sudo -u www-data pm2 stop servicedesk

# Update application (after git changes)
cd /var/www/itservicedesk
sudo git pull
sudo npm install
sudo -u www-data pm2 restart servicedesk
```

## Troubleshooting

**If application won't start:**
```bash
# Check PM2 logs
sudo -u www-data pm2 logs servicedesk

# Check if port is in use
sudo ss -tlnp | grep :3000

# Restart from scratch
sudo -u www-data pm2 delete servicedesk
sudo -u www-data pm2 start ecosystem.config.cjs
```

**If database connection fails:**
```bash
# Test database connection
sudo -u postgres psql servicedesk -c "SELECT version();"

# Check PostgreSQL status
sudo systemctl status postgresql
```

**If nginx issues:**
```bash
# Check nginx status
sudo systemctl status nginx

# Check nginx error logs
sudo tail -f /var/log/nginx/error.log
```

## Server Information

- **Application Port:** 3000 (internal)
- **Web Access:** Port 80 via nginx
- **Database:** PostgreSQL on localhost:5432
- **Process Manager:** PM2
- **Web Server:** Nginx reverse proxy
- **Application Path:** `/var/www/itservicedesk`
- **Logs:** `/var/www/itservicedesk/logs/`