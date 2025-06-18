#!/bin/bash

echo "Port 5000 Ubuntu Authentication Fix"
echo "=================================="

cat << 'EOF'
# Run on Ubuntu server to completely fix authentication:

cd /var/www/itservicedesk

# Check PM2 logs for specific authentication errors
echo "=== CURRENT PM2 LOGS ==="
pm2 logs servicedesk --lines 15

# Check if port 5000 is properly bound
echo ""
echo "=== PORT BINDING CHECK ==="
netstat -tlnp | grep :5000
lsof -i :5000

# Test basic server connectivity
echo ""
echo "=== SERVER CONNECTIVITY TEST ==="
curl -s http://localhost:5000/api/auth/me | head -3

# Verify database users exist with correct passwords
echo ""
echo "=== DATABASE USER VERIFICATION ==="
sudo -u postgres psql -d servicedesk -c "
SELECT username, password, role, email 
FROM users 
WHERE username IN ('test.user', 'test.admin') 
ORDER BY username;
"

# Test all Node.js dependencies
echo ""
echo "=== DEPENDENCY TEST ==="
node -e "
try {
  console.log('Testing dependencies...');
  const express = require('express');
  const { Pool } = require('pg');
  const bcrypt = require('bcrypt');
  const session = require('express-session');
  console.log('All dependencies loaded successfully');
  
  // Test database connection
  const pool = new Pool({
    connectionString: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk'
  });
  
  pool.query('SELECT username, password FROM users WHERE username = \$1', ['test.user'])
    .then(result => {
      console.log('Database connection: SUCCESS');
      console.log('User found:', result.rows.length > 0);
      if (result.rows.length > 0) {
        const user = result.rows[0];
        console.log('Username:', user.username);
        console.log('Password check (password123):', user.password === 'password123');
      }
      pool.end();
    })
    .catch(err => {
      console.log('Database error:', err.message);
      pool.end();
    });
    
} catch (error) {
  console.log('Dependency error:', error.message);
}
"

# Check production build integrity
echo ""
echo "=== PRODUCTION BUILD CHECK ==="
if [ -f dist/production.js ]; then
    echo "Production build size:"
    ls -lh dist/production.js
    echo ""
    echo "Syntax check:"
    node --check dist/production.js && echo "✓ Production build is valid" || echo "✗ Production build has errors"
else
    echo "✗ Production build missing - rebuilding..."
    npx esbuild server/production.ts \
      --platform=node \
      --packages=external \
      --bundle \
      --format=esm \
      --outfile=dist/production.js \
      --keep-names
fi

# Create minimal authentication test to isolate issue
echo ""
echo "=== CREATING MINIMAL AUTH TEST ==="
cat > minimal-auth.js << 'MINIMAL_EOF'
const express = require('express');
const { Pool } = require('pg');

const app = express();
app.use(express.json());

const pool = new Pool({
    connectionString: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk'
});

app.post('/test-auth', async (req, res) => {
    console.log('[Minimal] Auth request:', req.body);
    
    try {
        const { username, password } = req.body;
        
        if (!username || !password) {
            console.log('[Minimal] Missing credentials');
            return res.status(400).json({ error: 'Missing credentials' });
        }
        
        const result = await pool.query('SELECT * FROM users WHERE username = $1', [username]);
        console.log('[Minimal] Database query result:', result.rows.length);
        
        if (result.rows.length === 0) {
            console.log('[Minimal] User not found');
            return res.status(401).json({ error: 'User not found' });
        }
        
        const user = result.rows[0];
        console.log('[Minimal] User:', user.username, 'Password match:', user.password === password);
        
        if (user.password !== password) {
            console.log('[Minimal] Invalid password');
            return res.status(401).json({ error: 'Invalid password' });
        }
        
        console.log('[Minimal] Authentication successful');
        res.json({ 
            success: true, 
            user: { username: user.username, role: user.role } 
        });
        
    } catch (error) {
        console.error('[Minimal] Error:', error);
        res.status(500).json({ error: error.message });
    }
});

app.listen(5004, () => {
    console.log('[Minimal] Test server on port 5004');
});
MINIMAL_EOF

# Start minimal test
echo ""
echo "=== TESTING MINIMAL AUTH SERVER ==="
node minimal-auth.js &
MINIMAL_PID=$!
sleep 6

# Test minimal authentication
MINIMAL_RESULT=$(curl -s -X POST http://localhost:5004/test-auth \
    -H "Content-Type: application/json" \
    -d '{"username":"test.user","password":"password123"}')

echo "Minimal auth result: $MINIMAL_RESULT"

# Kill minimal test
kill $MINIMAL_PID 2>/dev/null
rm -f minimal-auth.js

# Test main production server again
echo ""
echo "=== TESTING MAIN PRODUCTION SERVER ==="
MAIN_RESULT=$(curl -s -X POST http://localhost:5000/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"username":"test.user","password":"password123"}')

echo "Main server result: $MAIN_RESULT"

# Check PM2 logs after our tests
echo ""
echo "=== PM2 LOGS AFTER TESTS ==="
pm2 logs servicedesk --lines 8

# Test external HTTPS access
echo ""
echo "=== EXTERNAL HTTPS TEST ==="
HTTPS_RESULT=$(curl -k -s https://98.81.235.7/api/auth/login \
    -X POST \
    -H "Content-Type: application/json" \
    -d '{"username":"test.user","password":"password123"}')

echo "HTTPS result: $HTTPS_RESULT"

# Final diagnosis
echo ""
echo "=== FINAL DIAGNOSIS ==="
echo "Minimal auth test: $(echo "$MINIMAL_RESULT" | grep -q success && echo "WORKING" || echo "FAILED")"
echo "Main server test: $(echo "$MAIN_RESULT" | grep -q user && echo "WORKING" || echo "FAILED")"
echo "HTTPS access test: $(echo "$HTTPS_RESULT" | grep -q user && echo "WORKING" || echo "FAILED")"

if echo "$MAIN_RESULT" | grep -q "user"; then
    echo ""
    echo "SUCCESS: Ubuntu server authentication is working!"
    echo "Access: https://98.81.235.7"
    echo "Credentials: test.user/password123 or test.admin/password123"
elif echo "$MINIMAL_RESULT" | grep -q "success"; then
    echo ""
    echo "Issue identified: Database/auth logic works, but production server has problems"
    echo "Likely cause: Production build or PM2 configuration issue"
else
    echo ""
    echo "Issue identified: Database or authentication logic problem"
    echo "Check database connectivity and user data above"
fi

EOF