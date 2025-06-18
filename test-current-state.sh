#!/bin/bash

echo "Test Current Ubuntu Server State"
echo "==============================="

cat << 'EOF'
# Test the current state of Ubuntu server authentication:

cd /var/www/itservicedesk

echo "=== SERVER STATUS FROM LOGS ==="
echo "✓ HTTP server running on port 5000"
echo "✓ Database connection established"
echo "✓ All schedulers initialized"
echo "✓ Network bound to all interfaces"
echo ""

# Test if server is responding to basic requests
echo "=== TESTING SERVER RESPONSE ==="
curl -s http://localhost:5000/api/auth/me -w "\nHTTP Code: %{http_code}\n"

# Clear PM2 logs to see fresh authentication attempts
echo ""
echo "=== CLEARING PM2 LOGS FOR FRESH TEST ==="
pm2 flush

# Test authentication and capture detailed logs
echo ""
echo "=== TESTING AUTHENTICATION WITH FRESH LOGS ==="
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.user","password":"password123"}' \
  -w "\nHTTP Code: %{http_code}\n"

# Wait a moment for logs to appear
sleep 3

# Check for authentication-specific logs
echo ""
echo "=== FRESH PM2 LOGS AFTER AUTH ATTEMPT ==="
pm2 logs servicedesk --lines 10

# Test with admin user
echo ""
echo "=== TESTING ADMIN USER ==="
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.admin","password":"password123"}' \
  -w "\nHTTP Code: %{http_code}\n"

# Check database users directly
echo ""
echo "=== VERIFYING DATABASE USERS ==="
sudo -u postgres psql -d servicedesk -c "
SELECT username, password, role, email 
FROM users 
WHERE username IN ('test.user', 'test.admin') 
ORDER BY username;
"

# Test database connectivity from Node.js
echo ""
echo "=== TESTING DATABASE FROM NODE.JS ==="
node -e "
const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk'
});

async function testAuth() {
  try {
    console.log('Testing database authentication logic...');
    
    // Test user lookup
    const result = await pool.query('SELECT * FROM users WHERE username = \$1', ['test.user']);
    console.log('User lookup result:', result.rows.length > 0 ? 'Found' : 'Not found');
    
    if (result.rows.length > 0) {
      const user = result.rows[0];
      console.log('Username:', user.username);
      console.log('Stored password:', user.password);
      console.log('Test password: password123');
      console.log('Password match:', user.password === 'password123');
      console.log('Role:', user.role);
    }
    
    await pool.end();
    console.log('Database test completed successfully');
  } catch (error) {
    console.error('Database test error:', error.message);
    await pool.end();
  }
}

testAuth();
"

# Check if there are any authentication route errors
echo ""
echo "=== TESTING API ENDPOINTS ==="
echo "Testing /api/auth/me endpoint:"
curl -s http://localhost:5000/api/auth/me

echo ""
echo "Testing basic server health:"
curl -s http://localhost:5000/ -I | head -3

# Test external HTTPS access
echo ""
echo "=== TESTING EXTERNAL HTTPS ACCESS ==="
curl -k -X POST https://98.81.235.7/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.user","password":"password123"}' \
  -w "\nHTTP Code: %{http_code}\n" \
  -s

# Final status check
echo ""
echo "=== FINAL STATUS CHECK ==="
pm2 status

# Get any recent authentication logs
echo ""
echo "=== RECENT AUTHENTICATION LOGS ==="
pm2 logs servicedesk --lines 5

EOF