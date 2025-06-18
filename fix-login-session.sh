#!/bin/bash

echo "Fix Login Session - Ubuntu Server Authentication"
echo "==============================================="

cat << 'EOF'
# Run on Ubuntu server to fix authentication issues:

cd /var/www/itservicedesk

# Check current PM2 logs for authentication errors
echo "Checking PM2 logs for authentication errors:"
pm2 logs servicedesk --lines 10

# Install bcrypt if missing (needed for password comparison)
echo ""
echo "Installing bcrypt dependency:"
npm install bcrypt

# Check what users exist in the database
echo ""
echo "Checking database users:"
sudo -u postgres psql -d servicedesk -c "SELECT id, username, email, password FROM users LIMIT 5;" 2>/dev/null || echo "Database query failed"

# Create a test user with plain text password for verification
echo ""
echo "Creating test user with plain text password:"
sudo -u postgres psql -d servicedesk -c "
INSERT INTO users (username, email, password, role, name) 
VALUES ('test.plain', 'test.plain@company.com', 'password123', 'user', 'Test Plain User')
ON CONFLICT (username) DO UPDATE SET password = 'password123';
" 2>/dev/null || echo "User creation failed"

# Rebuild production server with authentication fixes
echo ""
echo "Rebuilding production server with authentication fixes:"
npx esbuild server/production.ts \
  --platform=node \
  --packages=external \
  --bundle \
  --format=esm \
  --outfile=dist/production.js \
  --keep-names \
  --sourcemap

# Restart PM2 with fresh build
echo ""
echo "Restarting PM2 with fresh build:"
pm2 restart servicedesk

# Wait for restart
sleep 10

# Test with plain text user first
echo ""
echo "Testing with plain text user:"
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.plain","password":"password123"}' \
  -w "\nHTTP Status: %{http_code}\n"

# Test with original user
echo ""
echo "Testing with original user:"
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.user","password":"password123"}' \
  -w "\nHTTP Status: %{http_code}\n"

# Test with admin user
echo ""
echo "Testing with admin user:"
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.admin","password":"password123"}' \
  -w "\nHTTP Status: %{http_code}\n"

# Check external HTTPS
echo ""
echo "Testing external HTTPS:"
curl -k https://98.81.235.7/api/auth/me -w "\nHTTP Status: %{http_code}\n"

# Show final status
echo ""
echo "PM2 Status:"
pm2 status

echo ""
echo "Recent application logs:"
pm2 logs servicedesk --lines 5

EOF