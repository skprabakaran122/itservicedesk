#!/bin/bash

echo "Complete Ubuntu Server Authentication Fix"
echo "======================================="

cat << 'EOF'
# Final fix for Ubuntu server authentication:

cd /var/www/itservicedesk

# Check current PM2 errors
echo "Current PM2 logs:"
pm2 logs servicedesk --lines 8

# Ensure bcrypt dependency is available
npm install bcrypt

# Verify test users exist with correct passwords
sudo -u postgres psql -d servicedesk -c "
UPDATE users SET password = 'password123' 
WHERE username IN ('test.user', 'test.admin', 'john.doe');
SELECT username, password FROM users WHERE username = 'test.user';
"

# Rebuild production with corrected configuration
npx esbuild server/production.ts \
  --platform=node \
  --packages=external \
  --bundle \
  --format=esm \
  --outfile=dist/production.js \
  --keep-names

# Create production PM2 config matching development
cat > production.config.cjs << 'CONFIG_EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'dist/production.js',
    instances: 1,
    autorestart: true,
    max_restarts: 5,
    restart_delay: 3000,
    env: {
      NODE_ENV: 'production',
      PORT: 5000,
      DATABASE_URL: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk',
      SESSION_SECRET: 'calpion-service-desk-secret-key-2025'
    },
    error_file: '/tmp/servicedesk-error.log',
    out_file: '/tmp/servicedesk-out.log'
  }]
};
CONFIG_EOF

# Restart PM2 with new config
pm2 delete servicedesk
pm2 start production.config.cjs
pm2 save
sleep 12

# Test authentication
echo ""
echo "Testing authentication:"
AUTH_RESULT=$(curl -s -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.user","password":"password123"}')

echo "Auth response: $AUTH_RESULT"

# Test HTTPS
echo ""
echo "Testing HTTPS:"
HTTPS_RESULT=$(curl -k -s https://98.81.235.7/api/auth/login \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"username":"test.user","password":"password123"}')

echo "HTTPS response: $HTTPS_RESULT"

# Final status
echo ""
echo "PM2 Status:"
pm2 status

if echo "$AUTH_RESULT" | grep -q "user"; then
    echo ""
    echo "✅ SUCCESS: Authentication working on Ubuntu server!"
    echo "Login at https://98.81.235.7 with test.user/password123"
else
    echo ""
    echo "❌ Authentication still failing"
    echo "Recent logs:"
    pm2 logs servicedesk --lines 3
fi

EOF