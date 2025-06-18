#!/bin/bash

echo "Fix 502 Bad Gateway Error - Ubuntu Server"
echo "========================================"

cat << 'EOF'
# Run on Ubuntu server 98.81.235.7 to fix 502 error:

cd /var/www/itservicedesk

echo "Checking current status..."
pm2 status

echo "Checking if port 5000 is listening..."
netstat -tlnp | grep :5000 || ss -tlnp | grep :5000

echo "Checking PM2 logs for errors..."
pm2 logs servicedesk --lines 10

# Stop and restart the application properly
echo "Restarting application..."
pm2 delete servicedesk 2>/dev/null || true
sleep 3

# Kill any processes on port 5000
sudo fuser -k 5000/tcp 2>/dev/null || true
sleep 2

# Start fresh with correct configuration
cat > restart.config.cjs << 'RESTART_EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'dist/index.js',
    cwd: '/var/www/itservicedesk',
    instances: 1,
    autorestart: true,
    max_restarts: 5,
    env: {
      NODE_ENV: 'production',
      PORT: 5000,
      DATABASE_URL: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk',
      SESSION_SECRET: 'calpion-service-desk-secret-key-2025'
    }
  }]
};
RESTART_EOF

# Start application
pm2 start restart.config.cjs
pm2 save

# Wait for startup
sleep 15

echo "Testing port 5000 directly..."
curl -v http://localhost:5000/api/auth/me 2>&1 | head -20

echo "Checking if application is responding..."
netstat -tlnp | grep :5000 || ss -tlnp | grep :5000

echo "PM2 status after restart:"
pm2 status

echo "Recent application logs:"
pm2 logs servicedesk --lines 5

EOF