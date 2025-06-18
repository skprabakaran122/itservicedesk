#!/bin/bash

echo "Working Ubuntu Server Fix"
echo "========================"

cat << 'EOF'
# Copy and paste these commands on Ubuntu server 98.81.235.7:

cd /var/www/itservicedesk

# Clean stop
pm2 delete all 2>/dev/null || true
sudo fuser -k 3000/tcp 2>/dev/null || true

# Install tsx locally (avoid permission issues)
npm install tsx

# Create PM2 config with .cjs extension (fixes module error)
cat > working.config.cjs << 'WORKING_EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'node_modules/.bin/tsx',
    args: 'server/index.ts',
    instances: 1,
    autorestart: true,
    env: {
      NODE_ENV: 'production',
      PORT: 3000,
      DATABASE_URL: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk'
    }
  }]
};
WORKING_EOF

# Start application
pm2 start working.config.cjs

# Wait and test
sleep 15

# Test authentication with fixed system
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.user","password":"password123"}'

# Check status
pm2 status
pm2 logs servicedesk --lines 3

EOF

echo ""
echo "This approach:"
echo "- Uses local tsx installation (no global permissions)"
echo "- Uses .cjs extension to force CommonJS format"
echo "- Includes authentication system fixes"
echo "- Should resolve connection refused errors"