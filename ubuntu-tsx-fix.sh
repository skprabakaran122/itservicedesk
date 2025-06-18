#!/bin/bash

echo "Ubuntu Server - TSX Path Fix"
echo "============================"

cat << 'EOF'
# Run on Ubuntu server to find and use correct tsx path:

cd /var/www/itservicedesk

# Stop processes
pm2 delete all 2>/dev/null || true
sudo fuser -k 3000/tcp 2>/dev/null || true

# Check if tsx is installed and find its location
npm list tsx
find node_modules -name "tsx" -type f 2>/dev/null

# Install tsx if missing
npm install tsx

# Find the actual tsx executable path
TSX_PATH=$(find node_modules -name "tsx" -executable -type f 2>/dev/null | head -1)
echo "Found tsx at: $TSX_PATH"

# If tsx not found in expected location, try alternative
if [ ! -f "node_modules/.bin/tsx" ]; then
    echo "Creating tsx symlink..."
    ln -sf ../tsx/dist/cli.mjs node_modules/.bin/tsx 2>/dev/null || true
fi

# Create PM2 config with npx (more reliable)
cat > final.config.cjs << 'FINAL_EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'npx',
    args: 'tsx server/index.ts',
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
FINAL_EOF

# Start application with npx approach
pm2 start final.config.cjs

# Wait and test
sleep 20

echo "Testing authentication..."
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.user","password":"password123"}'

echo ""
echo "Application status:"
pm2 status
pm2 logs servicedesk --lines 5

EOF