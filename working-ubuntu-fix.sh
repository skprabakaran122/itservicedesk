#!/bin/bash

echo "Working Ubuntu Authentication Fix"
echo "==============================="

cat << 'EOF'
# Run on Ubuntu server to get authentication working like development:

cd /var/www/itservicedesk

# First check what's causing the authentication failure
echo "=== CHECKING PM2 LOGS ==="
pm2 logs servicedesk --lines 10

echo ""
echo "=== TESTING DATABASE CONNECTION ==="
sudo -u postgres psql -d servicedesk -c "SELECT username, password FROM users WHERE username = 'test.user';"

# Install missing dependencies if needed
echo ""
echo "=== INSTALLING DEPENDENCIES ==="
npm install bcrypt @types/bcrypt

# Rebuild production server with exact same configuration as development
echo ""
echo "=== REBUILDING PRODUCTION SERVER ==="
npx esbuild server/production.ts \
  --platform=node \
  --packages=external \
  --bundle \
  --format=esm \
  --outfile=dist/production.js \
  --keep-names \
  --sourcemap

# Update PM2 config with exact development environment variables
cat > production-fixed.config.cjs << 'PM2_EOF'
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
      SESSION_SECRET: 'calpion-service-desk-secret-key-2025',
      SENDGRID_API_KEY: 'SG.e1g2sll-fake-key-for-production',
      FROM_EMAIL: 'no-reply@calpion.com'
    },
    error_file: '/tmp/servicedesk-error.log',
    out_file: '/tmp/servicedesk-out.log',
    log_file: '/tmp/servicedesk-combined.log'
  }]
};
PM2_EOF

# Stop and restart PM2 with new configuration
echo ""
echo "=== RESTARTING PM2 ==="
pm2 delete servicedesk
pm2 start production-fixed.config.cjs
pm2 save

# Wait for startup
sleep 15

# Test authentication exactly like development
echo ""
echo "=== TESTING AUTHENTICATION ==="
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.user","password":"password123"}' \
  -s | head -10

# Test with test.admin
echo ""
echo "=== TESTING ADMIN LOGIN ==="
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.admin","password":"password123"}' \
  -s | head -10

# Test external HTTPS access
echo ""
echo "=== TESTING EXTERNAL HTTPS ==="
curl -k https://98.81.235.7/api/auth/login \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"username":"test.user","password":"password123"}' \
  -s | head -10

# Show final status
echo ""
echo "=== FINAL STATUS ==="
pm2 status

echo ""
echo "=== RECENT LOGS ==="
pm2 logs servicedesk --lines 5

# Check if authentication is now working
AUTH_TEST=$(curl -s -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.user","password":"password123"}')

if echo "$AUTH_TEST" | grep -q "user"; then
    echo ""
    echo "SUCCESS! Authentication is now working on Ubuntu server"
    echo "You can login at https://98.81.235.7 with:"
    echo "- test.user / password123"
    echo "- test.admin / password123"
else
    echo ""
    echo "Authentication still failing. Response: $AUTH_TEST"
    echo "Check PM2 logs above for errors."
fi

EOF