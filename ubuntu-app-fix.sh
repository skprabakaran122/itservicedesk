#!/bin/bash

echo "Ubuntu Server - Final Application Fix"
echo "===================================="

# Navigate to the project directory on Ubuntu server
cd /var/www/itservicedesk || { echo "Error: Project directory not found"; exit 1; }

# Stop any crashing processes
sudo -u ubuntu pm2 delete all 2>/dev/null || true

echo "Checking project structure..."
ls -la

echo "Building application properly..."
# Install all dependencies including devDependencies for build
sudo -u ubuntu npm install

# Build the frontend and backend
sudo -u ubuntu npm run build

echo "Checking build output..."
if [ -f "dist/index.js" ]; then
    echo "✓ Backend build successful"
else
    echo "✗ Backend build failed"
    exit 1
fi

if [ -d "dist/public" ]; then
    echo "✓ Frontend build successful"
else
    echo "✗ Frontend build failed"
    exit 1
fi

echo "Testing application startup..."
# Test the built application directly
cd /var/www/itservicedesk
export NODE_ENV=production
export PORT=3000
export DATABASE_URL=postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk

# Run a quick test
timeout 10s sudo -u ubuntu -E node dist/index.js &
APP_PID=$!
sleep 5

if kill -0 $APP_PID 2>/dev/null; then
    echo "✓ Application starts successfully"
    kill $APP_PID
else
    echo "✗ Application fails to start - checking for errors"
    # Try to see what's wrong
    sudo -u ubuntu -E node dist/index.js 2>&1 | head -10
fi

echo "Creating working PM2 configuration..."
sudo -u ubuntu tee working.config.js << 'EOF'
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

# Start application
echo "Starting application with PM2..."
sudo -u ubuntu pm2 start working.config.js

# Save PM2 configuration
sudo -u ubuntu pm2 save

echo "Waiting for application to start..."
sleep 10

# Test application
if curl -f http://localhost:3000 > /dev/null 2>&1; then
    echo "✓ Application responding on port 3000"
    
    # Test HTTPS through Nginx
    if curl -k -f https://localhost > /dev/null 2>&1; then
        echo "✓ HTTPS working through Nginx"
        echo ""
        echo "🎉 DEPLOYMENT SUCCESSFUL!"
        echo "================================="
        echo "Your IT Service Desk is available at:"
        echo "https://98.81.235.7"
        echo ""
        echo "Default login:"
        echo "Username: john.doe"
        echo "Password: password123"
        echo ""
        echo "Management commands:"
        echo "sudo -u ubuntu pm2 status"
        echo "sudo -u ubuntu pm2 logs servicedesk"
        echo "sudo -u ubuntu pm2 restart servicedesk"
    else
        echo "✗ HTTPS not working - check Nginx configuration"
        sudo nginx -t
    fi
else
    echo "✗ Application not responding"
    echo "PM2 Status:"
    sudo -u ubuntu pm2 status
    echo ""
    echo "Recent logs:"
    sudo -u ubuntu pm2 logs servicedesk --lines 15
fi