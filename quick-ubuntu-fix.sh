#!/bin/bash

# Quick Ubuntu Server Fix - Run on 98.81.235.7
echo "Quick TypeScript Direct Execution Fix"

# Stop everything
pm2 delete all
sudo fuser -k 3000/tcp

cd /var/www/itservicedesk

# Install tsx globally if not present
npm install -g tsx

# Install dependencies
npm install

# Create simple PM2 config for direct TypeScript execution
cat > tsx.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'tsx',
    args: 'server/index.ts',
    env: {
      NODE_ENV: 'production',
      PORT: 3000,
      DATABASE_URL: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk'
    }
  }]
};
EOF

# Start application
pm2 start tsx.config.js
pm2 save

# Test after 10 seconds
sleep 10
curl -X POST http://localhost:3000/api/auth/login -H "Content-Type: application/json" -d '{"username":"test.user","password":"password123"}'