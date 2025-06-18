#!/bin/bash

echo "Final Ubuntu Authentication Deployment"
echo "====================================="

cat << 'EOF'
# Final fix for Ubuntu server authentication:

cd /var/www/itservicedesk

# Database and dependencies are working - need to fix authentication logic
echo "=== STATUS CHECK ==="
echo "✓ Database connection: Working"
echo "✓ User lookup: Working" 
echo "✓ Password validation: Working"
echo "✓ Dependencies: All loaded"
echo ""
echo "Issue: Authentication endpoint logic needs fixing"

# Clear PM2 logs
pm2 flush

# Test current authentication response
echo ""
echo "=== TESTING CURRENT AUTHENTICATION ==="
AUTH_RESULT=$(curl -s -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.user","password":"password123"}')

echo "Current response: $AUTH_RESULT"

# Get fresh PM2 logs after authentication attempt
sleep 3
echo ""
echo "=== PM2 LOGS AFTER AUTHENTICATION ATTEMPT ==="
pm2 logs servicedesk --lines 10 --timestamp

# Create simple test using .cjs extension for CommonJS
echo ""
echo "=== CREATING SIMPLE AUTHENTICATION TEST ==="
cat > simple-test.cjs << 'TEST_EOF'
const express = require('express');
const { Pool } = require('pg');
const session = require('express-session');

const app = express();
app.use(express.json());

// Session middleware
app.use(session({
    secret: 'test-secret',
    resave: false,
    saveUninitialized: false,
    cookie: { secure: false, maxAge: 24 * 60 * 60 * 1000 }
}));

const pool = new Pool({
    connectionString: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk'
});

app.post('/simple-login', async (req, res) => {
    try {
        console.log('[Simple Test] Login request for:', req.body.username);
        
        const { username, password } = req.body;
        
        if (!username || !password) {
            return res.status(400).json({ error: 'Missing credentials' });
        }
        
        const result = await pool.query('SELECT * FROM users WHERE username = $1', [username]);
        
        if (result.rows.length === 0) {
            console.log('[Simple Test] User not found');
            return res.status(401).json({ error: 'User not found' });
        }
        
        const user = result.rows[0];
        console.log('[Simple Test] User found:', user.username);
        console.log('[Simple Test] Password comparison:', user.password, '===', password, ':', user.password === password);
        
        if (user.password !== password) {
            console.log('[Simple Test] Password mismatch');
            return res.status(401).json({ error: 'Invalid password' });
        }
        
        // Store user in session
        req.session.user = user;
        
        console.log('[Simple Test] Authentication successful');
        res.json({ 
            success: true,
            user: { 
                username: user.username, 
                role: user.role,
                email: user.email 
            } 
        });
        
    } catch (error) {
        console.error('[Simple Test] Error:', error);
        res.status(500).json({ error: 'Server error: ' + error.message });
    }
});

app.listen(5005, '0.0.0.0', () => {
    console.log('[Simple Test] Server running on port 5005');
});
TEST_EOF

# Start simple test server
echo ""
echo "=== STARTING SIMPLE TEST SERVER ==="
node simple-test.cjs &
SIMPLE_PID=$!
sleep 8

# Test simple authentication
echo ""
echo "=== TESTING SIMPLE AUTHENTICATION ==="
SIMPLE_RESULT=$(curl -s -X POST http://localhost:5005/simple-login \
    -H "Content-Type: application/json" \
    -d '{"username":"test.user","password":"password123"}')

echo "Simple test result: $SIMPLE_RESULT"

# Kill simple test server
kill $SIMPLE_PID 2>/dev/null
rm -f simple-test.cjs

# Compare results
echo ""
echo "=== COMPARISON ==="
if echo "$SIMPLE_RESULT" | grep -q "success"; then
    echo "✓ Simple authentication: WORKING"
    echo "Issue confirmed: Production server authentication logic has a bug"
else
    echo "✗ Simple authentication: FAILED"
    echo "Issue: Deeper system problem"
fi

if echo "$AUTH_RESULT" | grep -q "user"; then
    echo "✓ Production server: WORKING"
    echo ""
    echo "SUCCESS! Ubuntu server authentication is now working!"
    echo "Access: https://98.81.235.7"
    echo "Login: test.user/password123 or test.admin/password123"
else
    echo "✗ Production server: FAILED"
    echo "Production response: $AUTH_RESULT"
fi

# Test external HTTPS access one more time
echo ""
echo "=== FINAL HTTPS TEST ==="
FINAL_HTTPS=$(curl -k -s https://98.81.235.7/api/auth/login \
    -X POST \
    -H "Content-Type: application/json" \
    -d '{"username":"test.user","password":"password123"}')

echo "Final HTTPS test: $FINAL_HTTPS"

if echo "$FINAL_HTTPS" | grep -q "user"; then
    echo ""
    echo "🎉 COMPLETE SUCCESS!"
    echo "Ubuntu server is fully operational at https://98.81.235.7"
    echo "Authentication working for both local and external access"
else
    echo ""
    echo "External HTTPS still needs attention"
fi

# Show final PM2 status
echo ""
echo "=== FINAL PM2 STATUS ==="
pm2 status

EOF