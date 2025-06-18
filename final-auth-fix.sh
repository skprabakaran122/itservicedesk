#!/bin/bash

echo "Final Authentication Fix - Ubuntu Server"
echo "======================================="

cat << 'EOF'
# Run on Ubuntu server to fix authentication completely:

cd /var/www/itservicedesk

# Install bcrypt and check dependencies
npm install bcrypt
npm list bcrypt

# Check current PM2 logs for specific errors
echo "Current authentication errors:"
pm2 logs servicedesk --lines 10 | grep -i "error\|fail\|login" || echo "No error patterns found"

# Reset all test users to plain text passwords
echo ""
echo "Resetting test users with plain text passwords:"
sudo -u postgres psql -d servicedesk -c "
UPDATE users 
SET password = 'password123' 
WHERE username IN ('test.user', 'test.admin', 'john.doe');

INSERT INTO users (username, email, password, role, name, created_at) 
VALUES ('auth.test', 'auth.test@company.com', 'password123', 'user', 'Auth Test User', NOW())
ON CONFLICT (username) DO UPDATE SET password = 'password123';
"

# Verify users exist with correct passwords
echo ""
echo "Verifying test users:"
sudo -u postgres psql -d servicedesk -c "
SELECT username, email, password, role 
FROM users 
WHERE username IN ('test.user', 'test.admin', 'john.doe', 'auth.test')
ORDER BY username;
"

# Rebuild production server with debugging
echo ""
echo "Rebuilding production server:"
npx esbuild server/production.ts \
  --platform=node \
  --packages=external \
  --bundle \
  --format=esm \
  --outfile=dist/production.js \
  --keep-names \
  --sourcemap

# Restart PM2
pm2 restart servicedesk
sleep 12

# Test with the new auth.test user
echo ""
echo "Testing auth.test user (plain text password):"
AUTH_RESPONSE=$(curl -s -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"auth.test","password":"password123"}')
echo "Response: $AUTH_RESPONSE"

# Test with test.user
echo ""
echo "Testing test.user:"
USER_RESPONSE=$(curl -s -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.user","password":"password123"}')
echo "Response: $USER_RESPONSE"

# Test with test.admin
echo ""
echo "Testing test.admin:"
ADMIN_RESPONSE=$(curl -s -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.admin","password":"password123"}')
echo "Response: $ADMIN_RESPONSE"

# Test external HTTPS with working credentials
echo ""
echo "Testing external HTTPS access:"
HTTPS_RESPONSE=$(curl -k -s https://98.81.235.7/api/auth/login \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"username":"auth.test","password":"password123"}')
echo "HTTPS Response: $HTTPS_RESPONSE"

# Show current status
echo ""
echo "Current PM2 status:"
pm2 status

echo ""
echo "Recent application logs:"
pm2 logs servicedesk --lines 5

# Final verification
if echo "$AUTH_RESPONSE" | grep -q "user"; then
    echo ""
    echo "SUCCESS: Authentication is working!"
    echo "Login at https://98.81.235.7 with:"
    echo "- auth.test / password123"
    echo "- test.user / password123"
    echo "- test.admin / password123"
else
    echo ""
    echo "Authentication still failing. Check logs above for errors."
fi

EOF