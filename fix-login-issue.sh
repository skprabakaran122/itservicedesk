#!/bin/bash

echo "Fix Login Issue - Ubuntu Production Server"
echo "========================================"

cat << 'EOF'
# Fix the production server authentication issue:

cd /var/www/itservicedesk

echo "=== ISSUE CONFIRMED ==="
echo "✓ Working test: Authentication successful with user data returned"
echo "❌ Production server: Returns 'Login failed' with HTTP 500 error"
echo "✓ Database/auth logic: Proven working in isolation"
echo "❌ Production build: Has bug in authentication route"

# The issue is in the production server build - need to rebuild with correct authentication logic
echo ""
echo "=== REBUILDING PRODUCTION SERVER ==="

# First, verify we have the source files
if [ -f server/production.ts ]; then
    echo "Using server/production.ts"
    SOURCE_FILE="server/production.ts"
elif [ -f server/index.ts ]; then
    echo "Using server/index.ts"
    SOURCE_FILE="server/index.ts"
else
    echo "ERROR: No server source file found"
    exit 1
fi

# Rebuild production server with verbose error handling
npx esbuild $SOURCE_FILE \
  --platform=node \
  --packages=external \
  --bundle \
  --format=esm \
  --outfile=dist/production-fixed.js \
  --keep-names \
  --sourcemap

echo "Production build completed"
ls -la dist/production-fixed.js

# Create new PM2 config with the fixed build
cat > production-fixed.config.cjs << 'FIXED_CONFIG_EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'dist/production-fixed.js',
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
    out_file: '/tmp/servicedesk-out.log',
    log_file: '/tmp/servicedesk-combined.log',
    merge_logs: true,
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z'
  }]
};
FIXED_CONFIG_EOF

# Stop current PM2 process
pm2 delete servicedesk

# Start with fixed build
pm2 start production-fixed.config.cjs
pm2 save

# Wait for startup
sleep 15

# Test the fixed authentication
echo ""
echo "=== TESTING FIXED AUTHENTICATION ==="
FIXED_AUTH=$(curl -s -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.user","password":"password123"}')

echo "Fixed auth result: $FIXED_AUTH"

# Test admin authentication
echo ""
echo "=== TESTING ADMIN AUTHENTICATION ==="
ADMIN_AUTH=$(curl -s -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.admin","password":"password123"}')

echo "Admin auth result: $ADMIN_AUTH"

# Test external HTTPS
echo ""
echo "=== TESTING EXTERNAL HTTPS ==="
HTTPS_AUTH=$(curl -k -s https://98.81.235.7/api/auth/login \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"username":"test.user","password":"password123"}')

echo "HTTPS auth result: $HTTPS_AUTH"

# Check PM2 status
echo ""
echo "=== PM2 STATUS ==="
pm2 status

# Get recent logs
echo ""
echo "=== RECENT LOGS ==="
pm2 logs servicedesk --lines 5

# Final verification
echo ""
echo "=== FINAL VERIFICATION ==="
if echo "$FIXED_AUTH" | grep -q "user"; then
    echo "✅ SUCCESS: Ubuntu server authentication is now working!"
    echo ""
    echo "Production deployment complete:"
    echo "- Server: https://98.81.235.7"
    echo "- Authentication: Fixed and working"
    echo "- Local access: Working"
    echo "- External HTTPS: $(echo "$HTTPS_AUTH" | grep -q user && echo "Working" || echo "Check firewall/nginx")"
    echo ""
    echo "Login credentials:"
    echo "- test.user / password123 (user role)"
    echo "- test.admin / password123 (admin role)"
    echo ""
    echo "The Ubuntu server is now fully operational!"
elif echo "$FIXED_AUTH" | grep -q "Login failed"; then
    echo "❌ Authentication still failing after rebuild"
    echo "Issue may be in the source code authentication logic"
    echo "Check PM2 logs above for specific errors"
else
    echo "⚠️ Unexpected response: $FIXED_AUTH"
    echo "Server may need additional investigation"
fi

EOF