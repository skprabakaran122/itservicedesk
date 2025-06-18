#!/bin/bash

echo "Final PM2 Authentication Fix - Ubuntu Server"
echo "==========================================="

cat << 'EOF'
# Complete diagnostic and fix for Ubuntu server authentication:

cd /var/www/itservicedesk

# Get detailed PM2 logs to identify the exact error
echo "=== DETAILED PM2 ERROR ANALYSIS ==="
pm2 logs servicedesk --lines 25 --timestamp

echo ""
echo "=== ERROR LOG FILE CONTENTS ==="
if [ -f /tmp/servicedesk-error.log ]; then
    tail -20 /tmp/servicedesk-error.log
else
    echo "No error log file found"
fi

echo ""
echo "=== OUTPUT LOG FILE CONTENTS ==="
if [ -f /tmp/servicedesk-out.log ]; then
    tail -15 /tmp/servicedesk-out.log
else
    echo "No output log file found"
fi

# Test all dependencies individually
echo ""
echo "=== TESTING ALL DEPENDENCIES ==="
node -e "
const modules = ['express', 'pg', 'bcrypt', 'express-session', 'connect-pg-simple'];
console.log('Testing Node.js modules...');

modules.forEach(mod => {
  try {
    require(mod);
    console.log('✓', mod, 'loaded successfully');
  } catch (error) {
    console.log('✗', mod, 'failed:', error.message);
  }
});

console.log('\\nTesting database connection...');
const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk'
});

pool.query('SELECT 1 as test')
  .then(() => {
    console.log('✓ Database connection successful');
    return pool.query('SELECT username FROM users WHERE username = \$1', ['test.user']);
  })
  .then(result => {
    console.log('✓ User query successful, found:', result.rows.length, 'users');
    if (result.rows.length > 0) {
      console.log('✓ test.user exists in database');
    }
    pool.end();
  })
  .catch(error => {
    console.log('✗ Database error:', error.message);
    pool.end();
  });
"

# Check if the production build file exists and is valid
echo ""
echo "=== PRODUCTION BUILD VERIFICATION ==="
if [ -f dist/production.js ]; then
    echo "Production build exists:"
    ls -la dist/production.js
    echo ""
    echo "Checking for syntax errors:"
    node --check dist/production.js && echo "✓ No syntax errors" || echo "✗ Syntax errors found"
else
    echo "✗ Production build file not found!"
fi

# Test the authentication route in isolation
echo ""
echo "=== ISOLATED AUTHENTICATION TEST ==="
cat > isolated-auth-test.js << 'ISOLATED_EOF'
const express = require('express');
const session = require('express-session');
const { Pool } = require('pg');

console.log('[Isolated Test] Starting authentication test server...');

const app = express();
app.use(express.json());

// Basic session setup
app.use(session({
    secret: 'test-secret-key',
    resave: false,
    saveUninitialized: false,
    cookie: { secure: false, maxAge: 24 * 60 * 60 * 1000 }
}));

const pool = new Pool({
    connectionString: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk'
});

app.post('/isolated-login', async (req, res) => {
    console.log('[Isolated Test] Login request received:', req.body);
    
    try {
        const { username, password } = req.body;
        
        if (!username || !password) {
            console.log('[Isolated Test] Missing credentials');
            return res.status(400).json({ error: 'Missing credentials' });
        }
        
        console.log('[Isolated Test] Querying database for user:', username);
        const result = await pool.query('SELECT * FROM users WHERE username = $1', [username]);
        
        if (result.rows.length === 0) {
            console.log('[Isolated Test] User not found in database');
            return res.status(401).json({ error: 'User not found' });
        }
        
        const user = result.rows[0];
        console.log('[Isolated Test] User found:', user.username);
        console.log('[Isolated Test] Stored password:', user.password);
        console.log('[Isolated Test] Provided password:', password);
        console.log('[Isolated Test] Password match:', user.password === password);
        
        if (user.password !== password) {
            console.log('[Isolated Test] Password mismatch');
            return res.status(401).json({ error: 'Invalid password' });
        }
        
        // Store user in session
        req.session.user = user;
        
        console.log('[Isolated Test] Login successful for:', user.username);
        res.json({ 
            success: true, 
            message: 'Login successful',
            user: { 
                username: user.username, 
                role: user.role,
                email: user.email 
            } 
        });
        
    } catch (error) {
        console.error('[Isolated Test] Authentication error:', error.message);
        console.error('[Isolated Test] Stack trace:', error.stack);
        res.status(500).json({ error: 'Server error: ' + error.message });
    }
});

app.get('/isolated-status', (req, res) => {
    res.json({ status: 'Isolated test server running', timestamp: new Date().toISOString() });
});

const testPort = 5003;
app.listen(testPort, '0.0.0.0', () => {
    console.log('[Isolated Test] Server running on port', testPort);
});
ISOLATED_EOF

# Start isolated test server
echo ""
echo "=== STARTING ISOLATED TEST SERVER ==="
node isolated-auth-test.js &
ISOLATED_PID=$!
sleep 8

# Test the isolated server
echo ""
echo "=== TESTING ISOLATED SERVER ==="
ISOLATED_RESULT=$(curl -s -X POST http://localhost:5003/isolated-login \
    -H "Content-Type: application/json" \
    -d '{"username":"test.user","password":"password123"}')

echo "Isolated test result: $ISOLATED_RESULT"

# Test status endpoint
echo ""
echo "=== TESTING ISOLATED STATUS ==="
curl -s http://localhost:5003/isolated-status

# Kill isolated test server
kill $ISOLATED_PID 2>/dev/null
sleep 2
rm -f isolated-auth-test.js

# Compare with main production server
echo ""
echo ""
echo "=== TESTING MAIN PRODUCTION SERVER ==="
MAIN_RESULT=$(curl -s -X POST http://localhost:5000/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"username":"test.user","password":"password123"}')

echo "Main server result: $MAIN_RESULT"

# Get fresh PM2 logs after tests
echo ""
echo "=== FRESH PM2 LOGS AFTER TESTS ==="
pm2 logs servicedesk --lines 10 --timestamp

# Final comparison and diagnosis
echo ""
echo "=== DIAGNOSTIC COMPARISON ==="
if echo "$ISOLATED_RESULT" | grep -q "success"; then
    echo "✓ Isolated authentication server: WORKING"
    echo "  - Database connection: OK"
    echo "  - User lookup: OK"
    echo "  - Password validation: OK"
    echo "  - Session management: OK"
else
    echo "✗ Isolated authentication server: FAILED"
    echo "  - Issue: $ISOLATED_RESULT"
fi

if echo "$MAIN_RESULT" | grep -q "user"; then
    echo "✓ Main production server: WORKING"
    echo ""
    echo "SUCCESS! Authentication is now working on Ubuntu server!"
    echo "Access your application at: https://98.81.235.7"
    echo "Login with: test.user/password123 or test.admin/password123"
else
    echo "✗ Main production server: FAILED"
    echo "  - Response: $MAIN_RESULT"
    echo ""
    echo "DIAGNOSIS: The isolated test shows whether the issue is:"
    echo "1. Database/authentication logic (if isolated test fails)"
    echo "2. Production build/PM2 configuration (if isolated test works but main fails)"
    echo ""
    echo "Next steps based on isolated test results above."
fi

EOF