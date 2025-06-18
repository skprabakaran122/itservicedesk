#!/bin/bash

echo "Ubuntu Server Fix - No Global Permissions Required"
echo "================================================="

cat << 'EOF'
# Run on Ubuntu server - no sudo/global installs needed

cd /var/www/itservicedesk

# Stop all processes
pm2 delete all 2>/dev/null || true
sudo fuser -k 3000/tcp 2>/dev/null || true

# Install tsx locally (no global permissions needed)
npm install tsx

# Create proper CommonJS PM2 config (fix module error)
cat > pm2.config.cjs << 'CONFIG_EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: './node_modules/.bin/tsx',
    args: 'server/index.ts',
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
CONFIG_EOF

# Start with the .cjs extension (forces CommonJS)
pm2 start pm2.config.cjs
pm2 save

# Wait for startup
sleep 15

# Test application
echo "Testing authentication..."
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.user","password":"password123"}'

echo ""
echo "Status check:"
pm2 status

echo "Recent logs:"
pm2 logs servicedesk --lines 5

EOF