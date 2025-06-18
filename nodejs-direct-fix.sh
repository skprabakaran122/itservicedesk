#!/bin/bash

echo "Direct Node.js Solution for Ubuntu Server"
echo "========================================"

cat << 'EOF'
# Run on Ubuntu server - uses Node.js directly without tsx:

cd /var/www/itservicedesk

# Stop processes
pm2 delete all 2>/dev/null || true
sudo fuser -k 3000/tcp 2>/dev/null || true

# Build the application properly this time
npm run build

# Verify build output exists
ls -la dist/

# Create PM2 config to run the built JavaScript directly
cat > nodejs.config.cjs << 'NODEJS_EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'dist/index.js',
    cwd: '/var/www/itservicedesk',
    instances: 1,
    autorestart: true,
    env: {
      NODE_ENV: 'production',
      PORT: 3000,
      DATABASE_URL: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk'
    }
  }]
};
NODEJS_EOF

# Start with built JavaScript
pm2 start nodejs.config.cjs

# Wait and test
sleep 15

echo "Testing authentication..."
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.user","password":"password123"}'

echo ""
pm2 status
pm2 logs servicedesk --lines 5

# If still failing, try alternative approach with development mode
if ! curl -s http://localhost:3000/api/auth/me > /dev/null; then
    echo "Trying development mode..."
    pm2 delete servicedesk
    
    cat > dev.config.cjs << 'DEV_EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'npm',
    args: 'run dev',
    cwd: '/var/www/itservicedesk',
    instances: 1,
    autorestart: true,
    env: {
      NODE_ENV: 'development',
      PORT: 3000,
      DATABASE_URL: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk'
    }
  }]
};
DEV_EOF
    
    pm2 start dev.config.cjs
    sleep 15
    
    curl -X POST http://localhost:3000/api/auth/login \
      -H "Content-Type: application/json" \
      -d '{"username":"test.user","password":"password123"}'
fi

EOF