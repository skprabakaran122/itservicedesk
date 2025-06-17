#!/bin/bash

# Debug application startup issues
echo "Debugging application startup..."

cd /var/www/servicedesk

# Check if tsx is installed
echo "1. Checking tsx installation..."
if command -v tsx &> /dev/null; then
    echo "✓ tsx is available"
    tsx --version
else
    echo "✗ tsx not found, installing..."
    sudo npm install -g tsx
fi

# Check if TypeScript files exist
echo "2. Checking application files..."
if [ -f "server/index.ts" ]; then
    echo "✓ server/index.ts exists"
else
    echo "✗ server/index.ts missing"
    ls -la server/
    exit 1
fi

# Check environment file
echo "3. Checking environment configuration..."
if [ -f ".env" ]; then
    echo "✓ .env file exists"
    echo "Environment variables:"
    grep -v "PASSWORD\|API_KEY" .env || echo "No sensitive variables found"
else
    echo "✗ .env file missing"
    echo "Creating basic .env file..."
    cat > .env << EOF
DATABASE_URL=postgresql://servicedesk:servicedesk_password_2024@localhost:5432/servicedesk
NODE_ENV=production
PORT=3000
EOF
fi

# Test direct application startup
echo "4. Testing direct application startup..."
echo "Starting application manually to check for errors..."

# Kill any existing PM2 processes
pm2 delete servicedesk 2>/dev/null || true

# Try to start the application directly
timeout 10s tsx server/index.ts &
APP_PID=$!

sleep 5

# Check if the application is running
if kill -0 $APP_PID 2>/dev/null; then
    echo "✓ Application started successfully"
    
    # Test if it responds
    if curl -s http://localhost:3000 > /dev/null; then
        echo "✓ Application responding on port 3000"
    else
        echo "✗ Application not responding on port 3000"
    fi
    
    kill $APP_PID 2>/dev/null || true
else
    echo "✗ Application failed to start"
    echo "Checking for error output..."
fi

# Check dependencies
echo "5. Checking dependencies..."
if [ -f "package.json" ]; then
    echo "Installing/updating dependencies..."
    npm install
    
    # Build the application
    echo "Building application..."
    npm run build || echo "Build failed, but continuing..."
else
    echo "✗ package.json missing"
    exit 1
fi

# Update PM2 configuration with absolute paths
echo "6. Updating PM2 configuration..."
cat > ecosystem.config.cjs << EOF
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: '/usr/bin/tsx',
    args: '/var/www/servicedesk/server/index.ts',
    cwd: '/var/www/servicedesk',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    error_file: '/var/log/servicedesk/error.log',
    out_file: '/var/log/servicedesk/out.log',
    log_file: '/var/log/servicedesk/combined.log',
    time: true,
    node_args: []
  }]
};
EOF

# Ensure log directory exists and has correct permissions
sudo mkdir -p /var/log/servicedesk
sudo chown -R ubuntu:ubuntu /var/log/servicedesk

# Start with PM2
echo "7. Starting with PM2..."
pm2 start ecosystem.config.cjs
pm2 save

# Wait and check status
sleep 5
echo "8. Final status check..."

# Check PM2 status
pm2 status

# Check application response
if curl -s http://localhost:3000 > /dev/null; then
    echo "✓ Application responding on port 3000"
    echo "Your IT Service Desk should now be accessible at http://$(hostname -I | awk '{print $1}')"
else
    echo "✗ Application still not responding"
    echo "Checking PM2 logs for errors..."
    pm2 logs servicedesk --lines 20
fi