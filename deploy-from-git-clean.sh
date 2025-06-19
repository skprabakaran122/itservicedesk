#!/bin/bash

# Clean deployment from git without hardcoded secrets
set -e

echo "=== Clean Git Deployment ==="

# Set variables
DEPLOY_DIR="/var/www/itservicedesk"
DB_NAME="servicedesk"
DB_USER="servicedesk"

# Create deployment directory
mkdir -p "$DEPLOY_DIR"
cd "$DEPLOY_DIR"

# Clone or update repository
if [ -d ".git" ]; then
    echo "Updating existing repository..."
    git pull origin main
else
    echo "Cloning repository..."
    git clone https://github.com/skprabakaran122/itservicedesk.git .
fi

# Install dependencies
echo "Installing dependencies..."
npm install

# Build application with redirect fix
echo "Building application..."
npm run build

# Configure PostgreSQL
echo "Configuring PostgreSQL..."
systemctl start postgresql
systemctl enable postgresql

# Configure trust authentication
PG_CONFIG="/etc/postgresql/*/main/pg_hba.conf"
if [ -f $PG_CONFIG ]; then
    cp $PG_CONFIG $PG_CONFIG.backup
    sed -i 's/local   all             postgres                                peer/local   all             postgres                                trust/' $PG_CONFIG
    sed -i 's/local   all             all                                     peer/local   all             all                                     trust/' $PG_CONFIG
    systemctl restart postgresql
fi

# Create database and user
sudo -u postgres createuser --superuser "$DB_USER" 2>/dev/null || true
sudo -u postgres createdb "$DB_NAME" --owner="$DB_USER" 2>/dev/null || true

# Create environment file (user must provide SENDGRID_API_KEY)
cat > .env << EOL
NODE_ENV=production
DATABASE_URL=postgresql://$DB_USER@localhost:5432/$DB_NAME
PGHOST=localhost
PGPORT=5432
PGDATABASE=$DB_NAME
PGUSER=$DB_USER
SENDGRID_API_KEY=\${SENDGRID_API_KEY:-}
SESSION_SECRET=calpion-production-secret-\$(openssl rand -hex 32)
PORT=5000
EOL

# Configure nginx without redirects
cat > /etc/nginx/nginx.conf << 'NGINX_EOF'
events {
    worker_connections 1024;
}

http {
    upstream app {
        server 127.0.0.1:5000;
    }

    server {
        listen 80;
        server_name _;

        location / {
            proxy_pass http://app;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }
}
NGINX_EOF

# Remove conflicting nginx configurations
rm -rf /etc/nginx/sites-enabled
rm -rf /etc/nginx/sites-available
rm -rf /etc/nginx/conf.d

# Start services
nginx -t
systemctl restart nginx

# Start application with PM2
pm2 stop servicedesk 2>/dev/null || true
pm2 start ecosystem.production.config.cjs

sleep 15

# Test deployment
echo ""
echo "Testing deployment..."
curl -s -I http://localhost:5000/api/health
curl -s -I http://98.81.235.7/

echo ""
echo "=== Deployment Complete ==="
echo "Access: http://98.81.235.7"
echo "Login: test.admin / password123"
