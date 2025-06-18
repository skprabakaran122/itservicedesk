#!/bin/bash

echo "Quick Authentication Test - Ubuntu Server"
echo "======================================="

cat << 'EOF'
# Quick test to identify authentication issue on Ubuntu server:

cd /var/www/itservicedesk

# Clear PM2 logs for fresh authentication test
echo "Clearing PM2 logs for fresh test..."
pm2 flush

# Test authentication and capture response
echo ""
echo "Testing authentication:"
AUTH_RESPONSE=$(curl -s -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.user","password":"password123"}' \
  -w "\nHTTP_CODE:%{http_code}")

echo "Authentication response: $AUTH_RESPONSE"

# Wait for logs to populate
sleep 5

# Get fresh PM2 logs after authentication attempt
echo ""
echo "Fresh PM2 logs after authentication:"
pm2 logs servicedesk --lines 15 --timestamp

# Test database users exist
echo ""
echo "Database users verification:"
sudo -u postgres psql -d servicedesk -c "
SELECT username, password, role FROM users 
WHERE username IN ('test.user', 'test.admin') 
ORDER BY username;
"

# Test database connection from Node.js
echo ""
echo "Node.js database test:"
node -e "
const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk'
});

pool.query('SELECT username, password FROM users WHERE username = \$1', ['test.user'])
  .then(result => {
    if (result.rows.length > 0) {
      const user = result.rows[0];
      console.log('User found:', user.username);
      console.log('Password match (password123):', user.password === 'password123');
    } else {
      console.log('User not found');
    }
    pool.end();
  })
  .catch(err => {
    console.log('Database error:', err.message);
    pool.end();
  });
"

# Test HTTPS external access
echo ""
echo "Testing external HTTPS:"
HTTPS_RESPONSE=$(curl -k -s https://98.81.235.7/api/auth/login \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"username":"test.user","password":"password123"}')

echo "HTTPS response: $HTTPS_RESPONSE"

# Analysis
echo ""
echo "Analysis:"
if echo "$AUTH_RESPONSE" | grep -q "user"; then
    echo "✅ Authentication WORKING on Ubuntu server"
    echo "Login at https://98.81.235.7 with test.user/password123"
else
    echo "❌ Authentication still failing"
    echo "Check PM2 logs above for specific error details"
fi

EOF