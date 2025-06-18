#!/bin/bash

echo "Complete Ubuntu Authentication Fix"
echo "================================="

cat << 'EOF'
# Complete fix for Ubuntu server authentication:

cd /var/www/itservicedesk

# Install bcrypt dependency
npm install bcrypt

# Check current authentication errors
echo "PM2 logs:"
pm2 logs servicedesk --lines 5

# Reset all users to plain text passwords for compatibility
echo ""
echo "Resetting user passwords to plain text:"
sudo -u postgres psql -d servicedesk -c "
UPDATE users SET password = 'password123' WHERE username IN ('test.user', 'test.admin', 'john.doe');
DELETE FROM users WHERE username = 'test.simple';
INSERT INTO users (username, email, password, role, name, created_at) 
VALUES ('test.simple', 'test.simple@company.com', 'password123', 'user', 'Test Simple User', NOW());
"

# Verify user data
echo ""
echo "Current test users:"
sudo -u postgres psql -d servicedesk -c "SELECT username, password, role FROM users WHERE username LIKE 'test.%' OR username = 'john.doe';"

# Rebuild production server
echo ""
echo "Rebuilding production server:"
npx esbuild server/production.ts \
  --platform=node \
  --packages=external \
  --bundle \
  --format=esm \
  --outfile=dist/production.js \
  --keep-names

# Restart application
pm2 restart servicedesk
sleep 10

# Test all authentication scenarios
echo ""
echo "Testing test.simple user:"
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.simple","password":"password123"}' \
  -w "\nStatus: %{http_code}\n"

echo ""
echo "Testing test.user:"
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.user","password":"password123"}' \
  -w "\nStatus: %{http_code}\n"

echo ""
echo "Testing test.admin:"
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.admin","password":"password123"}' \
  -w "\nStatus: %{http_code}\n"

echo ""
echo "Testing external HTTPS:"
curl -k https://98.81.235.7/api/auth/login \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"username":"test.simple","password":"password123"}' \
  -w "\nStatus: %{http_code}\n"

echo ""
echo "Final PM2 status:"
pm2 status

echo ""
echo "Recent logs:"
pm2 logs servicedesk --lines 3

EOF