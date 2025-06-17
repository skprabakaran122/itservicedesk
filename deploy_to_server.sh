#!/bin/bash

# IT Service Desk - Automated Server Deployment Script
# This script automates the complete deployment process on Ubuntu servers

set -e  # Exit on any error

echo "==============================================="
echo "IT Service Desk - Automated Server Deployment"
echo "==============================================="
echo ""

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo "Please run this script as a regular user with sudo privileges, not as root"
   exit 1
fi

# Function to prompt for user input
prompt_input() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    
    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " input
        input=${input:-$default}
    else
        read -p "$prompt: " input
    fi
    
    eval "$var_name='$input'"
}

# Collect deployment information
echo "Please provide the following information for deployment:"
echo ""

prompt_input "Server domain name or IP address" "$(hostname -I | awk '{print $1}')" "SERVER_DOMAIN"
prompt_input "Database password for servicedesk user" "servicedesk_$(date +%s)" "DB_PASSWORD"
prompt_input "SendGrid API Key (leave empty to configure later)" "" "SENDGRID_KEY"
prompt_input "Git repository URL (if deploying from Git)" "" "GIT_REPO"

echo ""
echo "Deployment Configuration:"
echo "- Domain/IP: $SERVER_DOMAIN"
echo "- Database: PostgreSQL with user 'servicedesk'"
echo "- Web Server: Nginx with SSL"
echo "- Process Manager: PM2"
echo ""
read -p "Continue with deployment? (y/N): " confirm
if [[ $confirm != [yY] ]]; then
    echo "Deployment cancelled"
    exit 0
fi

echo ""
echo "Starting deployment..."

# Update system
echo "1. Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install required packages
echo "2. Installing required packages..."
sudo apt install -y nginx postgresql postgresql-contrib git curl ufw

# Install Node.js 20
echo "3. Installing Node.js 20..."
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install PM2
echo "4. Installing PM2..."
sudo npm install -g pm2

# Setup PostgreSQL
echo "5. Setting up PostgreSQL database..."
sudo systemctl start postgresql
sudo systemctl enable postgresql

sudo -u postgres psql << EOF
DROP DATABASE IF EXISTS servicedesk;
DROP USER IF EXISTS servicedesk;
CREATE USER servicedesk WITH PASSWORD '$DB_PASSWORD';
CREATE DATABASE servicedesk OWNER servicedesk;
GRANT ALL PRIVILEGES ON DATABASE servicedesk TO servicedesk;
ALTER USER servicedesk CREATEDB SUPERUSER;
\q
EOF

# Configure PostgreSQL
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = 'localhost'/" /etc/postgresql/*/main/postgresql.conf
sudo systemctl restart postgresql

# Create application directory
echo "6. Setting up application directory..."
sudo mkdir -p /var/www/servicedesk
sudo chown -R $USER:$USER /var/www/servicedesk

# Deploy application
echo "7. Deploying application..."
cd /var/www/servicedesk

if [ -n "$GIT_REPO" ]; then
    echo "Cloning from Git repository..."
    git clone "$GIT_REPO" .
else
    echo "Please upload your application files to /var/www/servicedesk"
    echo "Or provide the files via scp/rsync"
    read -p "Press Enter when files are ready..."
fi

# Install dependencies
echo "8. Installing application dependencies..."
npm install

# Create environment file
echo "9. Creating environment configuration..."
cat > .env << EOF
DATABASE_URL=postgresql://servicedesk:$DB_PASSWORD@localhost:5432/servicedesk
NODE_ENV=production
PORT=3000
BASE_URL=http://$SERVER_DOMAIN
EOF

if [ -n "$SENDGRID_KEY" ]; then
    echo "SENDGRID_API_KEY=$SENDGRID_KEY" >> .env
fi

# Run database migrations
echo "10. Running database migrations..."
npm run db:push

# Build application
echo "11. Building application..."
npm run build

# Create PM2 configuration
echo "12. Setting up PM2 process manager..."
cat > ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'tsx',
    args: 'server/index.ts',
    cwd: '/var/www/servicedesk',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    error_file: '/var/log/servicedesk/error.log',
    out_file: '/var/log/servicedesk/out.log',
    log_file: '/var/log/servicedesk/combined.log',
    time: true
  }]
};
EOF

# Create log directory
sudo mkdir -p /var/log/servicedesk
sudo chown -R $USER:$USER /var/log/servicedesk

# Configure Nginx
echo "13. Configuring Nginx..."
sudo tee /etc/nginx/sites-available/servicedesk << EOF
server {
    listen 80;
    server_name $SERVER_DOMAIN;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # Security headers
        add_header X-Frame-Options DENY;
        add_header X-Content-Type-Options nosniff;
        add_header X-XSS-Protection "1; mode=block";
    }

    # Serve static files
    location /static/ {
        alias /var/www/servicedesk/dist/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # File uploads
    client_max_body_size 10M;
}
EOF

# Enable site
sudo ln -sf /etc/nginx/sites-available/servicedesk /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t

# Setup SSL certificate
echo "14. Setting up SSL certificate..."
sudo mkdir -p /etc/nginx/ssl

# Generate self-signed certificate
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/servicedesk.key \
    -out /etc/nginx/ssl/servicedesk.crt \
    -subj "/C=US/ST=State/L=City/O=ServiceDesk/CN=$SERVER_DOMAIN" 2>/dev/null

# Update Nginx for HTTPS
sudo tee /etc/nginx/sites-available/servicedesk << EOF
server {
    listen 80;
    server_name $SERVER_DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl;
    server_name $SERVER_DOMAIN;

    ssl_certificate /etc/nginx/ssl/servicedesk.crt;
    ssl_certificate_key /etc/nginx/ssl/servicedesk.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        add_header X-Frame-Options DENY;
        add_header X-Content-Type-Options nosniff;
        add_header X-XSS-Protection "1; mode=block";
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains";
    }

    location /static/ {
        alias /var/www/servicedesk/dist/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    client_max_body_size 10M;
}
EOF

# Configure firewall
echo "15. Configuring firewall..."
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable

# Start services
echo "16. Starting services..."
sudo systemctl restart nginx
pm2 start ecosystem.config.js
pm2 save
pm2 startup | grep -E "sudo.*systemctl" | bash || true

# Create maintenance scripts
echo "17. Creating maintenance scripts..."

# Update script
cat > update.sh << 'EOF'
#!/bin/bash
cd /var/www/servicedesk
echo "Updating IT Service Desk..."
git pull origin main 2>/dev/null || echo "No git repository configured"
npm install
npm run build
npm run db:push
pm2 restart servicedesk
echo "Update complete"
EOF
chmod +x update.sh

# Backup script
cat > backup.sh << EOF
#!/bin/bash
DATE=\$(date +%Y%m%d_%H%M%S)
mkdir -p /var/backups
pg_dump -U servicedesk -h localhost servicedesk > /var/backups/servicedesk_\$DATE.sql
find /var/backups -name "servicedesk_*.sql" -mtime +7 -delete
echo "Backup completed: servicedesk_\$DATE.sql"
EOF
chmod +x backup.sh

# Add backup to crontab
(crontab -l 2>/dev/null; echo "0 2 * * * /var/www/servicedesk/backup.sh") | crontab -

# Test deployment
echo "18. Testing deployment..."
sleep 5

# Test database connection
if pg_isready -h localhost -p 5432 -U servicedesk; then
    echo "✓ Database connection successful"
else
    echo "✗ Database connection failed"
fi

# Test application
if curl -s http://localhost:3000 > /dev/null; then
    echo "✓ Application responding on port 3000"
else
    echo "✗ Application not responding on port 3000"
fi

# Test Nginx
if sudo nginx -t 2>/dev/null; then
    echo "✓ Nginx configuration valid"
else
    echo "✗ Nginx configuration invalid"
fi

echo ""
echo "==============================================="
echo "Deployment Complete!"
echo "==============================================="
echo ""
echo "Your IT Service Desk is now available at:"
echo "  HTTP:  http://$SERVER_DOMAIN"
echo "  HTTPS: https://$SERVER_DOMAIN"
echo ""
echo "Default admin credentials:"
echo "  Username: admin"
echo "  Password: admin (change immediately after login)"
echo ""
echo "Management commands:"
echo "  Status:  pm2 status"
echo "  Logs:    pm2 logs servicedesk"
echo "  Restart: pm2 restart servicedesk"
echo "  Update:  ./update.sh"
echo "  Backup:  ./backup.sh"
echo ""
echo "Important next steps:"
echo "1. Change the default admin password"
echo "2. Configure SendGrid API key in admin settings"
echo "3. Set up proper SSL certificate (Let's Encrypt recommended)"
echo "4. Configure email settings"
echo "5. Create user accounts and departments"
echo ""
echo "For SSL with Let's Encrypt, run:"
echo "  sudo apt install certbot python3-certbot-nginx"
echo "  sudo certbot --nginx -d $SERVER_DOMAIN"
echo ""
echo "Log locations:"
echo "  Application: /var/log/servicedesk/"
echo "  Nginx: /var/log/nginx/"
echo "  System: journalctl -u nginx"
echo ""