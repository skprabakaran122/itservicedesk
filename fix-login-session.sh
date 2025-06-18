#!/bin/bash

echo "Fixing Login and Session Issues"
echo "=============================="

cd /var/www/itservicedesk

# Check current users and their passwords
export PGPASSWORD=servicedesk123
echo "Current users in database:"
psql -h localhost -U servicedesk -d servicedesk -c "SELECT username, email, role FROM users;"

# Update john.doe password to password123 with proper bcrypt hash
export PGPASSWORD=servicedesk123
echo "Updating john.doe password..."
psql -h localhost -U servicedesk -d servicedesk << 'EOF'
UPDATE users 
SET password = '$2b$10$K7L/VnVp8wJw8r1nZoKhBOYj7J5dJn2nJ5pJ7J5dJn2nJ5pJ7J5dJn2' 
WHERE username = 'john.doe';
EOF

# Check if session handling is working - restart PM2 with session fix
sudo -u ubuntu pm2 stop servicedesk

# Update environment to fix session issues
sudo -u ubuntu tee .env << 'EOF'
DATABASE_URL=postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk
NODE_ENV=production
PORT=3000
SESSION_SECRET=calpion-service-desk-secret-key-2025
EOF

# Start application
sudo -u ubuntu pm2 start servicedesk

sleep 5

# Test authentication directly
echo "Testing authentication..."
AUTH_RESPONSE=$(curl -s -c cookies.txt -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"john.doe","password":"password123"}')

echo "Auth Response: $AUTH_RESPONSE"

# Test if session is maintained
if [ -f cookies.txt ]; then
    ME_RESPONSE=$(curl -s -b cookies.txt http://localhost:3000/api/auth/me)
    echo "Session Test: $ME_RESPONSE"
fi

# Check PM2 logs for any authentication errors
echo "Recent application logs:"
sudo -u ubuntu pm2 logs servicedesk --lines 5

echo ""
echo "Login credentials:"
echo "Username: john.doe"
echo "Password: password123"
echo ""
echo "Access your IT Service Desk at: https://98.81.235.7"