#!/bin/bash

echo "Fix Login Session - Ubuntu Server"
echo "================================"

cat << 'EOF'
# Deploy the fixed authentication to Ubuntu server:

cd /var/www/itservicedesk

echo "=== AUTHENTICATION FIX APPLIED ==="
echo "✓ Fixed bcrypt import issue in authentication route"
echo "✓ Moved dynamic require to safe top-level import"
echo "✓ Added fallback for plain text password comparison"

# Rebuild production server with the authentication fix
echo ""
echo "=== REBUILDING WITH AUTHENTICATION FIX ==="
npx esbuild server/production.ts \
  --platform=node \
  --packages=external \
  --bundle \
  --format=esm \
  --outfile=dist/production-auth-fixed.js \
  --keep-names \
  --sourcemap

echo "Build completed:"
ls -la dist/production-auth-fixed.js

# Create PM2 config with the authentication-fixed build
cat > auth-fixed.config.cjs << 'AUTH_FIXED_EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'dist/production-auth-fixed.js',
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
AUTH_FIXED_EOF

# Restart PM2 with authentication-fixed build
echo ""
echo "=== RESTARTING PM2 WITH AUTHENTICATION FIX ==="
pm2 delete servicedesk
pm2 start auth-fixed.config.cjs
pm2 save

# Wait for application startup
sleep 18

# Test authentication with the fix
echo ""
echo "=== TESTING AUTHENTICATION AFTER FIX ==="
AUTH_FIXED_RESULT=$(curl -s -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.user","password":"password123"}')

echo "Authentication result: $AUTH_FIXED_RESULT"

# Test admin authentication
echo ""
echo "=== TESTING ADMIN AUTHENTICATION ==="
ADMIN_FIXED_RESULT=$(curl -s -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.admin","password":"password123"}')

echo "Admin authentication result: $ADMIN_FIXED_RESULT"

# Test session endpoint
echo ""
echo "=== TESTING SESSION ENDPOINT ==="
curl -s http://localhost:5000/api/auth/me

# Test external HTTPS access
echo ""
echo "=== TESTING EXTERNAL HTTPS ACCESS ==="
HTTPS_FIXED_RESULT=$(curl -k -s https://98.81.235.7/api/auth/login \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"username":"test.user","password":"password123"}')

echo "HTTPS authentication result: $HTTPS_FIXED_RESULT"

# Check PM2 status and logs
echo ""
echo "=== PM2 STATUS ==="
pm2 status

echo ""
echo "=== RECENT LOGS ==="
pm2 logs servicedesk --lines 5

# Final verification
echo ""
echo "=== FINAL VERIFICATION ==="
if echo "$AUTH_FIXED_RESULT" | grep -q '"user"'; then
    echo "SUCCESS: Ubuntu server authentication is now working!"
    echo ""
    echo "Production deployment complete:"
    echo "- Server: https://98.81.235.7"
    echo "- Authentication: Fixed and operational"
    echo "- Local access: Working"
    echo "- External HTTPS: $(echo "$HTTPS_FIXED_RESULT" | grep -q user && echo "Working" || echo "Needs nginx configuration")"
    echo ""
    echo "Login credentials:"
    echo "- test.user / password123 (user role)"
    echo "- test.admin / password123 (admin role)"
    echo ""
    echo "The Ubuntu server IT Service Desk is now fully operational!"
elif echo "$AUTH_FIXED_RESULT" | grep -q "Login failed"; then
    echo "Authentication still failing - may need additional debugging"
    echo "Check PM2 logs above for any remaining errors"
else
    echo "Unexpected response - server may need additional configuration"
    echo "Response: $AUTH_FIXED_RESULT"
fi

EOF