#!/bin/bash

# Quick PM2 fix for the production deployment issue
# Addresses the MODULE_NOT_FOUND and DATABASE_URL errors

set -e

APP_DIR="/var/www/itservicedesk"
APP_NAME="itservicedesk"

echo "Fixing PM2 deployment issues..."

cd $APP_DIR

# Stop and clean all PM2 processes
echo "Cleaning PM2 state..."
pm2 kill
rm -rf ~/.pm2
pm2 resurrect

# Set environment variables
echo "Setting environment variables..."
export DATABASE_URL="postgresql://ubuntu:password@localhost:5432/servicedesk"
export NODE_ENV="production"
export PORT="5000"

# Verify the production server file exists
echo "Verifying production files..."
if [ ! -f "dist/production.cjs" ]; then
    echo "Creating production server..."
    mkdir -p dist
    cp server/production.cjs dist/production.cjs
fi

# Test the production server directly
echo "Testing production server directly..."
DATABASE_URL="postgresql://ubuntu:password@localhost:5432/servicedesk" NODE_ENV="production" node dist/production.cjs &
SERVER_PID=$!
sleep 5

# Check if server started
if ps -p $SERVER_PID > /dev/null; then
    echo "Production server working, stopping test..."
    kill $SERVER_PID
    sleep 2
else
    echo "Production server failed to start"
    exit 1
fi

# Create updated PM2 ecosystem config
echo "Creating PM2 configuration..."
cat > ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'itservicedesk',
    script: 'dist/production.cjs',
    instances: 1,
    exec_mode: 'fork',
    cwd: '/var/www/itservicedesk',
    env: {
      NODE_ENV: 'production',
      PORT: 5000,
      DATABASE_URL: 'postgresql://ubuntu:password@localhost:5432/servicedesk'
    },
    error_file: './logs/err.log',
    out_file: './logs/out.log',
    log_file: './logs/combined.log',
    time: true,
    max_memory_restart: '1G',
    restart_delay: 4000,
    watch: false,
    ignore_watch: ['node_modules', 'logs', 'dist'],
    kill_timeout: 5000
  }]
};
EOF

# Start with PM2
echo "Starting with PM2..."
pm2 start ecosystem.config.js
pm2 save

# Wait and test
sleep 10

# Check PM2 status
pm2 status

# Test application
if curl -s http://localhost:5000/health | grep -q "OK"; then
    echo "✓ Application started successfully"
    echo "✓ PM2 process is running"
    
    # Show logs
    echo "Recent logs:"
    pm2 logs $APP_NAME --lines 10
    
    # Test HTTPS
    if curl -k -s https://localhost/health | grep -q "OK"; then
        echo "✓ HTTPS proxy working"
        
        SERVER_IP=$(curl -s ifconfig.me || echo "your-server-ip")
        echo ""
        echo "🎉 Deployment fixed successfully!"
        echo "Access: https://$SERVER_IP"
        echo "Login: john.doe / password123"
    else
        echo "⚠ Application running but HTTPS proxy needs checking"
    fi
else
    echo "✗ Application still not responding"
    echo "PM2 status:"
    pm2 status
    echo "Error logs:"
    pm2 logs $APP_NAME --err --lines 20
fi