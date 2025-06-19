#!/bin/bash

# Simple production deployment using existing infrastructure
set -e

echo "=== Deploying IT Service Desk (Simple Production) ==="
echo "Repository: https://github.com/skprabakaran122/itservicedesk"
echo "Using existing server.cjs + PM2 configuration"
echo ""

# Stop existing services
echo "Stopping existing services..."
sudo pm2 stop all 2>/dev/null || true
sudo pm2 delete all 2>/dev/null || true
sudo systemctl stop itservicedesk 2>/dev/null || true

# Clean installation directory
echo "Preparing installation directory..."
sudo rm -rf /var/www/itservicedesk
sudo mkdir -p /var/www/itservicedesk
cd /var/www/itservicedesk

# Clone from GitHub
echo "Cloning clean repository..."
sudo git clone https://github.com/skprabakaran122/itservicedesk.git .

# Install dependencies
echo "Installing dependencies..."
sudo npm install
sudo npm install -g tsx pm2

# Build frontend only
echo "Building frontend..."
sudo npm run build

# Create logs directory
sudo mkdir -p logs

# Set up environment
echo "Configuring environment..."
sudo tee .env > /dev/null << 'EOF'
NODE_ENV=production
PORT=5000
DATABASE_URL=postgresql://servicedesk:SecurePass123@localhost:5432/servicedesk
SENDGRID_API_KEY=SG.placeholder
EOF

# Set permissions
sudo chown -R www-data:www-data /var/www/itservicedesk
sudo chmod -R 755 /var/www/itservicedesk

# Start with PM2
echo "Starting application with PM2..."
cd /var/www/itservicedesk
sudo -u www-data pm2 start ecosystem.config.cjs

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
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
        proxy_read_timeout 300;
    }
}
EOF

# Enable nginx site
sudo ln -sf /etc/nginx/sites-available/itservicedesk /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# Verify deployment
echo ""
echo "=== Deployment Complete ==="
echo "Application URL: http://98.81.235.7"
echo ""
echo "Login credentials:"
echo "  Admin: test.admin / password123"
echo "  User:  test.user / password123"
echo ""
echo "PM2 Status:"
sudo -u www-data pm2 status
echo ""
echo "Application logs (last 20 lines):"
sudo -u www-data pm2 logs --lines 20

echo ""
echo "Testing application health..."
sleep 5
curl -s http://localhost:5000/health || echo "Health check failed - check logs"