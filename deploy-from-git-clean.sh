#!/bin/bash

# Deploy IT Service Desk from clean GitHub repository
set -e

echo "=== Deploying IT Service Desk from Clean GitHub Repository ==="
echo "Repository: https://github.com/skprabakaran122/itservicedesk"
echo "Target Server: Ubuntu (98.81.235.7)"
echo ""

# Stop any existing services
echo "Stopping existing services..."
sudo systemctl stop itservicedesk 2>/dev/null || true
sudo pm2 stop all 2>/dev/null || true
sudo pm2 delete all 2>/dev/null || true

# Clean up existing installation
echo "Cleaning up existing installation..."
sudo rm -rf /var/www/itservicedesk
sudo mkdir -p /var/www/itservicedesk
cd /var/www/itservicedesk

# Clone fresh from GitHub
echo "Cloning fresh repository from GitHub..."
sudo git clone https://github.com/skprabakaran122/itservicedesk.git .

# Install dependencies
echo "Installing dependencies..."
sudo npm install

# Build frontend
echo "Building frontend..."
sudo npm run build

# Build backend
echo "Building backend for production..."
sudo npx esbuild server/index.ts --bundle --platform=node --target=node18 --outfile=dist/index.js --external:pg --external:bcrypt --external:multer --external:express --external:express-session --external:@sendgrid/mail

# Set up environment variables
echo "Setting up environment variables..."
sudo tee .env > /dev/null << EOF
NODE_ENV=production
PORT=5000
DATABASE_URL=postgresql://servicedesk:SecurePass123@localhost:5432/servicedesk
SENDGRID_API_KEY=SG.placeholder
EOF

# Set proper permissions
echo "Setting permissions..."
sudo chown -R www-data:www-data /var/www/itservicedesk
sudo chmod -R 755 /var/www/itservicedesk

# Install PM2 globally if not present
if ! command -v pm2 &> /dev/null; then
    echo "Installing PM2..."
    sudo npm install -g pm2
fi

# Start with PM2
echo "Starting application with PM2..."
sudo -u www-data pm2 start ecosystem.config.cjs --env production

# Configure nginx
echo "Configuring nginx..."
sudo tee /etc/nginx/sites-available/itservicedesk > /dev/null << 'EOF'
server {
    listen 80;
    server_name 98.81.235.7;

    location / {
        proxy_pass http://localhost:5000;
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
EOF

# Enable nginx site
sudo ln -sf /etc/nginx/sites-available/itservicedesk /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx

# Verify deployment
echo ""
echo "=== Deployment Complete ==="
echo "Application URL: http://98.81.235.7"
echo ""
echo "Test credentials:"
echo "  Username: test.admin"
echo "  Password: password123"
echo ""
echo "PM2 Status:"
sudo -u www-data pm2 status

echo ""
echo "Application logs:"
sudo -u www-data pm2 logs --lines 10