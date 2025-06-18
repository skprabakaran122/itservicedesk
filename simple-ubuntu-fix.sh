#!/bin/bash

echo "Simple Ubuntu Server Fix - Direct Node.js Approach"
echo "=================================================="

cat << 'EOF'
# Simple fix for module resolution issues
# Run on Ubuntu server 98.81.235.7:

# Stop all processes
pm2 delete all 2>/dev/null || true
sudo fuser -k 3000/tcp 2>/dev/null || true

cd /var/www/itservicedesk

# Skip the build process - run directly with tsx
npm install tsx -g
npm install

# Create simple PM2 config that runs TypeScript directly
cat > simple.config.js << 'SIMPLE_EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'tsx',
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
SIMPLE_EOF

# Start with the direct TypeScript approach
pm2 start simple.config.js
pm2 save

# Wait and test
sleep 10

echo "Testing direct TypeScript approach..."
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.user","password":"password123"}'

echo ""
echo "Status:"
pm2 status
pm2 logs servicedesk --lines 5

EOF

echo ""
echo "This approach:"
echo "- Bypasses build issues by running TypeScript directly"
echo "- Uses tsx (TypeScript executor) instead of compiled JavaScript"
echo "- Avoids module resolution problems"
echo "- Should work immediately without build artifacts"