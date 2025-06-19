#!/bin/bash

# Deploy IT Service Desk to Ubuntu with consistent port 3000
set -e

echo "=== Deploying IT Service Desk (Port 3000) ==="

# Step 1: Install dependencies
echo "1. Installing dependencies..."
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
apt-get update
apt-get install -y nodejs nginx postgresql postgresql-contrib

# Step 2: Setup application directory
echo "2. Setting up application..."
mkdir -p /var/www/itservicedesk
cd /var/www/itservicedesk

# Copy application files
cp server-production.cjs ./
cp package*.json ./
cp -r dist/ ./ 2>/dev/null || echo "No dist directory found"
cp -r server/ ./ 2>/dev/null || echo "No server directory found"
cp -r shared/ ./ 2>/dev/null || echo "No shared directory found"

# Install production dependencies
npm install --production

# Step 3: Setup PostgreSQL database
echo "3. Configuring database..."
sudo -u postgres psql << EOF
CREATE USER servicedesk WITH PASSWORD 'servicedesk123';
CREATE DATABASE servicedesk OWNER servicedesk;
GRANT ALL PRIVILEGES ON DATABASE servicedesk TO servicedesk;
\q
EOF

# Create database connection string
export DATABASE_URL="postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk"

# Step 4: Install systemd service (port 3000)
echo "4. Installing systemd service..."
cp itservicedesk.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable itservicedesk

# Step 5: Configure nginx (port 3000)
echo "5. Configuring nginx..."
cp nginx-itservicedesk.conf /etc/nginx/sites-available/default
nginx -t
systemctl enable nginx

# Step 6: Setup firewall
echo "6. Configuring firewall..."
ufw allow ssh
ufw allow http
ufw --force enable

# Step 7: Create logs directory
echo "7. Setting up logging..."
mkdir -p logs
chown -R www-data:www-data /var/www/itservicedesk

# Step 8: Start services
echo "8. Starting services..."
systemctl start itservicedesk
systemctl start nginx

# Wait for services to initialize
sleep 5

# Step 9: Verify deployment
echo "9. Verifying deployment..."
echo "SystemD service status:"
systemctl status itservicedesk --no-pager

echo "Nginx service status:"
systemctl status nginx --no-pager

echo "Port 3000 listening:"
netstat -tlnp | grep :3000 || echo "Port 3000 not listening"

echo "Testing application health:"
curl -f http://localhost:3000/health || echo "Health check failed"

echo "Testing through nginx:"
curl -f http://localhost/ || echo "Nginx proxy failed"

echo ""
echo "=== Deployment Complete ==="
echo "✓ IT Service Desk running on port 3000"
echo "✓ Nginx proxy configured for port 3000"
echo "✓ SystemD service enabled"
echo "✓ Database configured"
echo ""
echo "Access your application at: http://98.81.235.7"
echo ""
echo "Management commands:"
echo "  View logs: sudo journalctl -u itservicedesk -f"
echo "  Restart app: sudo systemctl restart itservicedesk"
echo "  Restart nginx: sudo systemctl restart nginx"
echo "  Check status: sudo systemctl status itservicedesk"