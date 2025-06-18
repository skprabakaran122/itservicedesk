#!/bin/bash

echo "Starting IT Service Desk Application"
echo "===================================="

cd /var/www/itservicedesk

# Create proper PM2 ecosystem file as CommonJS
sudo -u ubuntu tee ecosystem.config.cjs << 'EOF'
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

# Remove any existing PM2 processes
sudo -u ubuntu pm2 delete all 2>/dev/null || true

# Start application with the corrected config
echo "Starting application with PM2..."
sudo -u ubuntu pm2 start ecosystem.config.cjs

# Save PM2 configuration
sudo -u ubuntu pm2 save

echo "Application started"

# Test the application
echo "Testing application..."
sleep 10

if curl -f http://localhost:3000 > /dev/null 2>&1; then
    echo "✓ Application running successfully on port 3000"
    echo "✓ HTTPS proxy configured via Nginx"
    echo ""
    echo "🎉 DEPLOYMENT COMPLETE!"
    echo "======================================"
    echo "Your IT Service Desk is now available at:"
    echo "https://98.81.235.7"
    echo ""
    echo "Default login credentials:"
    echo "Username: john.doe"
    echo "Password: password123"
    echo ""
    echo "Management commands:"
    echo "sudo -u ubuntu pm2 status"
    echo "sudo -u ubuntu pm2 logs servicedesk"
    echo "sudo -u ubuntu pm2 restart servicedesk"
    echo ""
    echo "Note: Browsers will show a security warning for the self-signed certificate."
    echo "Click 'Advanced' then 'Proceed' to access the application."
else
    echo "✗ Application not responding - checking status..."
    sudo -u ubuntu pm2 status
    echo ""
    echo "Checking logs..."
    sudo -u ubuntu pm2 logs servicedesk --lines 20
fi