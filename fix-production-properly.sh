#!/bin/bash

# Fix production using the proper build process
set -e

cd /var/www/itservicedesk

echo "=== Using Proper Production Build Process ==="

# Stop existing processes
pm2 delete all 2>/dev/null || true

# Build the application properly using the package.json scripts
echo "Building application with proper npm scripts..."
npm run build

# Check if build was successful
if [ -f "dist/index.js" ]; then
    echo "✓ Build successful - dist/index.js created"
else
    echo "✗ Build failed - dist/index.js not found"
    ls -la dist/ 2>/dev/null || echo "No dist directory"
    exit 1
fi

# Update PM2 configuration to use the built application
echo "Creating proper PM2 configuration..."
cat > ecosystem.production.config.cjs << 'EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'dist/index.js',
    cwd: '/var/www/itservicedesk',
    instances: 1,
    exec_mode: 'fork',
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    restart_delay: 3000,
    max_restarts: 5,
    min_uptime: '20s',
    env: {
      NODE_ENV: 'production',
      PORT: 5000
    },
    error_file: './logs/error.log',
    out_file: './logs/out.log',
    log_file: './logs/app.log',
    time: true,
    merge_logs: true
  }]
};
EOF

# Test the built application directly first
echo "Testing built application..."
timeout 15s node dist/index.js &
TEST_PID=$!
sleep 8

if curl -s http://localhost:5000/api/health >/dev/null 2>&1; then
    echo "✓ Built application working correctly"
    kill $TEST_PID 2>/dev/null || true
else
    echo "✗ Built application failed"
    kill $TEST_PID 2>/dev/null || true
    echo "Checking application output:"
    node dist/index.js 2>&1 | head -20
    exit 1
fi

# Ensure logs directory
mkdir -p logs
chown -R www-data:www-data . 2>/dev/null || true

# Start with PM2 using proper configuration
echo "Starting with PM2..."
pm2 start ecosystem.production.config.cjs

# Wait for startup
sleep 15

# Check status
echo "PM2 Status:"
pm2 status

# Test endpoints
echo "Testing application..."
if curl -s http://localhost:5000/api/health >/dev/null; then
    echo "✓ Application running successfully"
    echo "Health check response:"
    curl -s http://localhost:5000/api/health
else
    echo "✗ Application not responding"
    pm2 logs servicedesk --lines 20 --nostream
    exit 1
fi

# Configure nginx for the working application
echo "Configuring nginx..."
systemctl restart nginx
sleep 3

echo "Final test through nginx:"
curl -s -I http://localhost/

echo ""
echo "=== Production Build Deployment Complete ==="
echo "✓ Used proper npm build process (creates ES module dist/index.js)"
echo "✓ PM2 running built application instead of raw TypeScript"
echo "✓ Same build process as development but in production mode"
echo ""
echo "Your IT Service Desk is now at: http://98.81.235.7"
echo "Monitor: pm2 logs servicedesk"