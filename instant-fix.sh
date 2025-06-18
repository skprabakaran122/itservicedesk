#!/bin/bash

# Instant fix for the PM2 deployment failure
# Addresses MODULE_NOT_FOUND and DATABASE_URL errors

cd /var/www/itservicedesk

# Kill all PM2 processes and clean state
pm2 kill
sleep 2

# Ensure production file exists
mkdir -p dist logs
cp server/production.cjs dist/production.cjs

# Create environment file
cat > .env << 'EOF'
DATABASE_URL=postgresql://ubuntu:password@localhost:5432/servicedesk
NODE_ENV=production
PORT=5000
EOF

# Use the existing .cjs config file
echo "Using ecosystem.config.cjs..."

# Start PM2 with explicit environment
export DATABASE_URL="postgresql://ubuntu:password@localhost:5432/servicedesk"
export NODE_ENV="production"
export PORT="5000"

pm2 start ecosystem.config.cjs
pm2 save

echo "Waiting for application to start..."
sleep 10

# Test the application
if curl -s http://localhost:5000/health | grep -q "OK"; then
    echo "SUCCESS: Application is now running"
    pm2 status
else
    echo "FAILED: Application still not responding"
    echo "Checking logs..."
    pm2 logs itservicedesk --lines 10
fi