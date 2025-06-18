#!/bin/bash

echo "Final PM2 Configuration Fix"
echo "=========================="

cd /var/www/itservicedesk

# Stop any running processes
sudo -u ubuntu pm2 delete all 2>/dev/null || true

# Create PM2 config with .cjs extension for CommonJS
sudo -u ubuntu tee pm2.config.cjs << 'EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: './dist/index.js',
    cwd: '/var/www/itservicedesk',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production',
      PORT: 3000,
      DATABASE_URL: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk'
    },
    error_file: '/var/www/itservicedesk/logs/error.log',
    out_file: '/var/www/itservicedesk/logs/output.log',
    log_file: '/var/www/itservicedesk/logs/combined.log',
    time: true
  }]
};
EOF

# Start with the .cjs config
echo "Starting application with PM2..."
sudo -u ubuntu pm2 start pm2.config.cjs

# Save configuration
sudo -u ubuntu pm2 save

echo "Waiting for application to fully start..."
sleep 10

# Test application
echo "Testing application..."
if curl -f http://localhost:3000 > /dev/null 2>&1; then
    echo "✓ Application responding on port 3000"
    
    # Test HTTPS
    if curl -k -f https://localhost > /dev/null 2>&1; then
        echo "✓ HTTPS working through Nginx"
        echo ""
        echo "🎉 DEPLOYMENT COMPLETE!"
        echo "====================================="
        echo "Your IT Service Desk is now running at:"
        echo "https://98.81.235.7"
        echo ""
        echo "Default Login Credentials:"
        echo "Username: john.doe"
        echo "Password: password123"
        echo ""
        echo "Features Available:"
        echo "- Enhanced Calpion branding with professional logo"
        echo "- Comprehensive dashboard with animated UI"
        echo "- Ticket management system"
        echo "- Change request workflows"
        echo "- User management"
        echo "- SLA tracking and metrics"
        echo "- HTTPS security with self-signed certificate"
        echo ""
        echo "Management Commands:"
        echo "sudo -u ubuntu pm2 status"
        echo "sudo -u ubuntu pm2 logs servicedesk"
        echo "sudo -u ubuntu pm2 restart servicedesk"
        echo ""
        echo "Note: Browser will show security warning for self-signed certificate."
        echo "Click 'Advanced' then 'Proceed' to access the application."
    else
        echo "✗ HTTPS not responding - checking Nginx"
        sudo nginx -t
        sudo systemctl status nginx
    fi
else
    echo "✗ Application not responding"
    sudo -u ubuntu pm2 status
    sudo -u ubuntu pm2 logs servicedesk --lines 10
fi

echo ""
echo "PM2 Status:"
sudo -u ubuntu pm2 status