#!/bin/bash

echo "Debugging and Fixing Application"
echo "================================"

cd /var/www/itservicedesk

# Stop the crashing application
sudo -u ubuntu pm2 delete servicedesk 2>/dev/null || true

echo "Checking build artifacts..."
if [ ! -f "dist/index.js" ]; then
    echo "Build output missing - rebuilding..."
    
    # Install all dependencies including dev dependencies for build
    sudo -u ubuntu npm install
    
    # Build the application
    sudo -u ubuntu npm run build
    
    if [ ! -f "dist/index.js" ]; then
        echo "Build failed - checking for errors..."
        sudo -u ubuntu npm run build 2>&1 | tail -20
        exit 1
    fi
else
    echo "✓ Build output exists"
fi

echo "Checking package.json scripts..."
cat package.json | grep -A 5 '"scripts"'

echo ""
echo "Testing application directly..."
cd /var/www/itservicedesk

# Test the built application directly
echo "Testing: node dist/index.js"
sudo -u ubuntu timeout 10s node dist/index.js 2>&1 || echo "Direct execution failed"

echo ""
echo "Testing: npm start"
sudo -u ubuntu timeout 10s npm start 2>&1 || echo "npm start failed"

echo ""
echo "Checking environment variables..."
sudo -u ubuntu cat .env

echo ""
echo "Checking database connection..."
sudo -u ubuntu psql postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk -c "SELECT 1;" 2>&1

echo ""
echo "Starting application in development mode to see errors..."
export NODE_ENV=development
export DATABASE_URL=postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk
export PORT=3000

# Try running the server directly to see actual errors
sudo -u ubuntu -E timeout 15s npm run dev 2>&1 | head -30 || echo "Development mode test completed"

echo ""
echo "Starting with PM2 using direct script instead of npm..."

# Create a direct PM2 config that runs the built file
sudo -u ubuntu tee pm2-direct.config.cjs << 'EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'dist/index.js',
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

# Start with the direct configuration
sudo -u ubuntu pm2 start pm2-direct.config.cjs

echo "Application started with direct script"
sleep 5

# Check status
sudo -u ubuntu pm2 status

echo ""
echo "Testing application response..."
if curl -f http://localhost:3000 > /dev/null 2>&1; then
    echo "✓ Application responding on port 3000"
    echo "✓ Testing HTTPS through Nginx..."
    if curl -k -f https://localhost > /dev/null 2>&1; then
        echo "✓ HTTPS working through Nginx"
        echo ""
        echo "🎉 SUCCESS! Your IT Service Desk is now running!"
        echo "Access at: https://98.81.235.7"
    else
        echo "✗ HTTPS not working - check Nginx"
    fi
else
    echo "✗ Application still not responding"
    echo "Latest logs:"
    sudo -u ubuntu pm2 logs servicedesk --lines 10
fi