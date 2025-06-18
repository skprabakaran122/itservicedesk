#!/bin/bash

echo "Ubuntu TSX Authentication Fix"
echo "============================"

cat << 'EOF'
# Run on Ubuntu server to fix authentication completely:

cd /var/www/itservicedesk

# Check PM2 logs for specific authentication errors
echo "=== PM2 AUTHENTICATION ERRORS ==="
pm2 logs servicedesk --lines 15

# Check error log file directly
echo ""
echo "=== ERROR LOG FILE ==="
cat /tmp/servicedesk-error.log 2>/dev/null | tail -10 || echo "No error log found"

# Test database connection and users
echo ""
echo "=== DATABASE VERIFICATION ==="
sudo -u postgres psql -d servicedesk -c "
SELECT username, password, role 
FROM users 
WHERE username IN ('test.user', 'test.admin') 
ORDER BY username;
"

# Test bcrypt module availability
echo ""
echo "=== BCRYPT MODULE TEST ==="
node -e "
try {
  const bcrypt = require('bcrypt');
  console.log('✅ bcrypt loaded successfully');
} catch (error) {
  console.log('❌ bcrypt error:', error.message);
  console.log('Stack:', error.stack);
}
"

# Test direct database query from Node.js
echo ""
echo "=== NODE.JS DATABASE TEST ==="
node -e "
const { Pool } = require('pg');
async function test() {
  const pool = new Pool({
    connectionString: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk'
  });
  
  try {
    const result = await pool.query('SELECT username, password FROM users WHERE username = \$1', ['test.user']);
    console.log('Database query successful');
    console.log('User found:', result.rows.length > 0);
    if (result.rows.length > 0) {
      console.log('Username:', result.rows[0].username);
      console.log('Password:', result.rows[0].password);
    }
    await pool.end();
  } catch (error) {
    console.log('Database error:', error.message);
    await pool.end();
  }
}
test();
"

# Create minimal test server to isolate authentication issue
echo ""
echo "=== CREATING MINIMAL TEST SERVER ==="
cat > test-auth-server.js << 'TEST_EOF'
const express = require('express');
const { Pool } = require('pg');

const app = express();
app.use(express.json());

const pool = new Pool({
  connectionString: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk'
});

app.post('/test-login', async (req, res) => {
  try {
    console.log('Test login request:', req.body);
    
    const { username, password } = req.body;
    
    if (!username || !password) {
      return res.status(400).json({ error: 'Missing credentials' });
    }
    
    const result = await pool.query('SELECT * FROM users WHERE username = $1', [username]);
    console.log('Database query result:', result.rows.length);
    
    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'User not found' });
    }
    
    const user = result.rows[0];
    console.log('User found:', user.username);
    console.log('Password comparison:', user.password, '===', password, user.password === password);
    
    if (user.password !== password) {
      return res.status(401).json({ error: 'Invalid password' });
    }
    
    res.json({ success: true, user: { username: user.username, role: user.role } });
    
  } catch (error) {
    console.error('Test login error:', error);
    res.status(500).json({ error: error.message });
  }
});

app.listen(5001, () => {
  console.log('Test server running on port 5001');
});
TEST_EOF

# Start test server
echo ""
echo "=== STARTING TEST SERVER ==="
node test-auth-server.js &
TEST_PID=$!
sleep 5

# Test the minimal server
echo ""
echo "=== TESTING MINIMAL SERVER ==="
curl -X POST http://localhost:5001/test-login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.user","password":"password123"}' \
  -s

# Kill test server
kill $TEST_PID 2>/dev/null
rm -f test-auth-server.js

# Check main production server status
echo ""
echo ""
echo "=== MAIN SERVER STATUS ==="
curl -s http://localhost:5000/api/auth/me | head -3

# Final verbose test
echo ""
echo "=== VERBOSE AUTHENTICATION TEST ==="
curl -v -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.user","password":"password123"}' 2>&1 | head -10

EOF