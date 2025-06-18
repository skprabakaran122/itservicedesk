#!/bin/bash

echo "Fixing Permissions and Completing Deployment"
echo "============================================="

# Fix ownership of the project directory
sudo chown -R ubuntu:ubuntu /var/www/itservicedesk
cd /var/www/itservicedesk

# Create environment file with proper permissions
sudo -u ubuntu tee .env << EOF
DATABASE_URL=postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk
NODE_ENV=production
PORT=3000
EOF

# Install dependencies as ubuntu user
echo "Installing dependencies..."
sudo -u ubuntu npm install --omit=dev

# Build application
echo "Building application..."
sudo -u ubuntu npm run build

# Push database schema
echo "Setting up database schema..."
sudo -u ubuntu npm run db:push

# Create PM2 ecosystem file
sudo -u ubuntu tee ecosystem.config.js << EOF
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
EOF

# Create logs directory
sudo -u ubuntu mkdir -p logs

# Start application with PM2 as ubuntu user
echo "Starting application..."
sudo -u ubuntu pm2 delete servicedesk 2>/dev/null || true
sudo -u ubuntu pm2 start ecosystem.config.js
sudo -u ubuntu pm2 save

# Setup PM2 startup for ubuntu user
sudo env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u ubuntu --hp /home/ubuntu

echo "Application setup complete"

# Test application
echo "Testing application..."
sleep 10

if curl -f http://localhost:3000 > /dev/null 2>&1; then
    echo "✓ Application running on port 3000"
    echo "✓ Deployment successful!"
    echo ""
    echo "Your IT Service Desk is available at:"
    echo "https://98.81.235.7"
    echo ""
    echo "Default login:"
    echo "Username: john.doe"
    echo "Password: password123"
else
    echo "✗ Application not responding - checking logs..."
    sudo -u ubuntu pm2 logs servicedesk --lines 20
fi

echo ""
echo "Management commands:"
echo "sudo -u ubuntu pm2 status"
echo "sudo -u ubuntu pm2 logs servicedesk"
echo "sudo -u ubuntu pm2 restart servicedesk"