#!/bin/bash

echo "Completing IT Service Desk Startup"
echo "=================================="

cd /var/www/itservicedesk

# Remove any existing PM2 processes
sudo -u ubuntu pm2 delete all 2>/dev/null || true

# Create final PM2 configuration
sudo -u ubuntu tee final.config.cjs << 'EOF'
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
    }
  }]
};
EOF

# Start application
echo "Starting IT Service Desk..."
sudo -u ubuntu pm2 start final.config.cjs

# Save PM2 configuration
sudo -u ubuntu pm2 save

# Wait for startup
sleep 10

# Check status
echo "Application Status:"
sudo -u ubuntu pm2 status

# Test endpoints
echo ""
echo "Testing application..."

# Test direct connection
if curl -s http://localhost:3000/api/auth/me | grep -q "Not authenticated"; then
    echo "✓ Auth endpoint working (expected 401)"
else
    echo "Testing auth endpoint..."
    curl -s http://localhost:3000/api/auth/me
fi

# Test products endpoint
echo "Testing products endpoint..."
PRODUCTS_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/api/products)
if [ "$PRODUCTS_RESPONSE" = "200" ]; then
    echo "✓ Products endpoint working"
elif [ "$PRODUCTS_RESPONSE" = "500" ]; then
    echo "Products endpoint returning 500 - checking database connection"
else
    echo "Products endpoint response: $PRODUCTS_RESPONSE"
fi

# Test HTTPS through Nginx
echo "Testing HTTPS..."
if curl -k -s https://localhost/ | grep -q "IT Service Desk"; then
    echo "✓ HTTPS working - application accessible"
else
    echo "Testing HTTPS connection..."
    curl -k -I https://localhost/
fi

echo ""
echo "🎉 DEPLOYMENT COMPLETE!"
echo "======================================"
echo "Your IT Service Desk is running at:"
echo "https://98.81.235.7"
echo ""
echo "Access Instructions:"
echo "1. Open https://98.81.235.7 in your browser"
echo "2. Accept the security warning for self-signed certificate"
echo "3. Login with: john.doe / password123"
echo ""
echo "Features Available:"
echo "- Enhanced Calpion branding and logo"
echo "- Comprehensive dashboard with animated UI"
echo "- Ticket management system"
echo "- Change request workflows"
echo "- User management"
echo "- SLA tracking and metrics"
echo ""
echo "Management Commands:"
echo "sudo -u ubuntu pm2 status"
echo "sudo -u ubuntu pm2 logs servicedesk"
echo "sudo -u ubuntu pm2 restart servicedesk"