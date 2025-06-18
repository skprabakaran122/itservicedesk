#!/bin/bash

echo "Complete Ubuntu Server Recovery"
echo "==============================="

cat << 'EOF'
# Complete recovery script for Ubuntu server
# Copy and run these commands on 98.81.235.7:

# Clean slate approach - stop everything
sudo fuser -k 3000/tcp 2>/dev/null || true
pm2 delete all 2>/dev/null || true
pm2 kill 2>/dev/null || true

cd /var/www/itservicedesk

# Install required tools globally
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs
sudo npm install -g pm2@latest

# Clean install
rm -rf node_modules package-lock.json dist
npm install

# Manual build process (bypassing npm scripts)
echo "Building frontend..."
./node_modules/.bin/vite build

echo "Building backend..."
./node_modules/.bin/esbuild server/index.ts --platform=node --packages=external --bundle --format=esm --outdir=dist

# Verify build
ls -la dist/

# Create PM2 config
cat > pm2.config.js << 'PM2_EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'dist/index.js',
    instances: 1,
    autorestart: true,
    env: {
      NODE_ENV: 'production',
      PORT: 3000,
      DATABASE_URL: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk'
    }
  }]
};
PM2_EOF

# Start application
pm2 start pm2.config.js
pm2 save

# Test after 10 seconds
sleep 10

echo "Testing application..."
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.user","password":"password123"}'

echo ""
echo "External test..."
curl -k https://98.81.235.7/api/auth/me

pm2 logs servicedesk --lines 5

EOF

echo ""
echo "This addresses:"
echo "- vite command not found"  
echo "- PM2 module format errors"
echo "- Port binding conflicts"
echo "- Authentication system deployment"
echo ""
echo "The Ubuntu server should be accessible at https://98.81.235.7 after running this script."