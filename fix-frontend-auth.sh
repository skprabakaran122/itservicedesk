#!/bin/bash

echo "Fixing Frontend Authentication Flow"
echo "=================================="

cd /var/www/itservicedesk

# Check if there's a session configuration issue in the server
sudo -u ubuntu pm2 stop servicedesk

# Update the environment with proper session configuration
sudo -u ubuntu tee .env << 'EOF'
DATABASE_URL=postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk
NODE_ENV=production
PORT=3000
SESSION_SECRET=calpion-service-desk-secret-key-2025
CORS_ORIGIN=https://98.81.235.7
EOF

# Check if there's a frontend routing issue - rebuild with production config
echo "Rebuilding frontend with production settings..."
sudo -u ubuntu npm run build

# Start application
sudo -u ubuntu pm2 start servicedesk

sleep 10

# Test the complete authentication flow
echo "Testing complete authentication flow..."

# Step 1: Get login page
echo "1. Testing login page access..."
curl -s -c test-cookies.txt -o /dev/null -w "Login page: %{http_code}\n" https://localhost/ -k

# Step 2: Login
echo "2. Testing login..."
LOGIN_RESULT=$(curl -s -b test-cookies.txt -c test-cookies.txt -w "%{http_code}" \
  -X POST https://localhost/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"john.doe","password":"password123"}' -k)

echo "Login result: $LOGIN_RESULT"

# Step 3: Check if authenticated
echo "3. Testing authentication status..."
AUTH_STATUS=$(curl -s -b test-cookies.txt -w "%{http_code}" \
  https://localhost/api/auth/me -k)

echo "Auth status: $AUTH_STATUS"

# Clean up
rm -f test-cookies.txt

echo ""
echo "Application status:"
sudo -u ubuntu pm2 status

echo ""
echo "Recent logs:"
sudo -u ubuntu pm2 logs servicedesk --lines 10

echo ""
echo "If login still redirects, try these steps:"
echo "1. Clear your browser cache and cookies"
echo "2. Open https://98.81.235.7 in incognito/private mode"
echo "3. Accept the certificate warning"
echo "4. Login with: john.doe / password123"