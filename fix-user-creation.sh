#!/bin/bash

echo "Fix User Creation and Authentication - Ubuntu Server"
echo "=================================================="

cat << 'EOF'
# Complete authentication fix for Ubuntu server:

cd /var/www/itservicedesk

# Check PM2 logs for specific errors
echo "Current PM2 logs:"
pm2 logs servicedesk --lines 5

# Install bcrypt dependency
npm install bcrypt

# Reset test users with plain text passwords
echo ""
echo "Resetting test users with plain text passwords:"
sudo -u postgres psql -d servicedesk << 'SQL_EOF'
UPDATE users SET password = 'password123' WHERE username IN ('test.user', 'test.admin', 'john.doe');
INSERT INTO users (username, email, password, role, name) 
VALUES ('test.simple', 'test.simple@company.com', 'password123', 'user', 'Test Simple User')
ON CONFLICT (username) DO UPDATE SET password = 'password123';
SQL_EOF

# Verify users in database
echo ""
echo "Current users in database:"
sudo -u postgres psql -d servicedesk -c "SELECT username, email, password, role FROM users WHERE username LIKE 'test.%';"

# Rebuild and restart
echo ""
echo "Rebuilding production server:"
npx esbuild server/production.ts \
  --platform=node \
  --packages=external \
  --bundle \
  --format=esm \
  --outfile=dist/production.js \
  --keep-names

pm2 restart servicedesk
sleep 8

# Test authentication with simple user
echo ""
echo "Testing simple user authentication:"
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.simple","password":"password123"}' \
  -s | head -5

echo ""
echo "Testing original test.user:"
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.user","password":"password123"}' \
  -s | head -5

echo ""
echo "Final verification - External HTTPS:"
curl -k https://98.81.235.7/api/auth/login \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"username":"test.simple","password":"password123"}' \
  -s | head -5

echo ""
echo "Application status:"
pm2 status

EOF