#!/bin/bash

echo "Debug and Fix 502 Bad Gateway"
echo "============================"

cat << 'EOF'
# Run on Ubuntu server to diagnose and fix 502 error:

cd /var/www/itservicedesk

# Check what's actually running
echo "=== DIAGNOSIS ==="
echo "PM2 processes:"
pm2 list

echo "Processes on port 5000:"
sudo netstat -tlnp | grep :5000 || sudo ss -tlnp | grep :5000

echo "Processes on port 3000:"
sudo netstat -tlnp | grep :3000 || sudo ss -tlnp | grep :3000

echo "PM2 logs (last 10 lines):"
pm2 logs --lines 10

echo "=== FIXING ==="
# Kill everything and restart clean
pm2 delete all 2>/dev/null || true
sudo fuser -k 5000/tcp 2>/dev/null || true
sudo fuser -k 3000/tcp 2>/dev/null || true

# Wait for cleanup
sleep 5

# Start fresh - using the simple working approach
cat > working.config.cjs << 'WORKING_EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'dist/index.js',
    instances: 1,
    autorestart: true,
    env: {
      NODE_ENV: 'production',
      PORT: 5000,
      DATABASE_URL: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk'
    }
  }]
};
WORKING_EOF

# Start application
pm2 start working.config.cjs
pm2 save

# Wait for startup
sleep 20

echo "=== VERIFICATION ==="
echo "Port 5000 status:"
sudo netstat -tlnp | grep :5000 || sudo ss -tlnp | grep :5000

echo "Testing application directly:"
curl -s http://localhost:5000/api/auth/me | head -5

echo "PM2 status:"
pm2 status

echo "Application logs:"
pm2 logs servicedesk --lines 3

echo "Testing from external (through nginx):"
curl -k -s https://98.81.235.7/api/auth/me | head -5

EOF