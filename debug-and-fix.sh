#!/bin/bash

echo "Debug and Fix Ubuntu Authentication"
echo "================================="

cat << 'EOF'
# Complete debugging and fix for Ubuntu server:

cd /var/www/itservicedesk

# Get detailed PM2 logs with timestamps
echo "=== PM2 LOGS WITH TIMESTAMPS ==="
pm2 logs servicedesk --lines 20 --timestamp

# Check if there are any module loading errors
echo ""
echo "=== ERROR LOG ANALYSIS ==="
if [ -f /tmp/servicedesk-error.log ]; then
    echo "Error log contents:"
    tail -15 /tmp/servicedesk-error.log
else
    echo "No error log file found"
fi

# Verify database users and passwords
echo ""
echo "=== DATABASE USER VERIFICATION ==="
sudo -u postgres psql -d servicedesk -c "
SELECT username, password, role, email 
FROM users 
WHERE username IN ('test.user', 'test.admin') 
ORDER BY username;
"

# Test Node.js dependencies
echo ""
echo "=== DEPENDENCY CHECK ==="
node -e "
try {
    console.log('Testing core modules...');
    const express = require('express');
    console.log('✓ express loaded');
    
    const { Pool } = require('pg');
    console.log('✓ pg loaded');
    
    const bcrypt = require('bcrypt');
    console.log('✓ bcrypt loaded');
    
    console.log('All dependencies loaded successfully');
} catch (error) {
    console.log('✗ Dependency error:', error.message);
}
"

# Test database connection independently
echo ""
echo "=== DATABASE CONNECTION TEST ==="
node -e "
const { Pool } = require('pg');
async function testDB() {
    const pool = new Pool({
        connectionString: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk'
    });
    
    try {
        const result = await pool.query('SELECT username, password FROM users WHERE username = \$1', ['test.user']);
        console.log('✓ Database connection successful');
        console.log('User found:', result.rows.length > 0);
        
        if (result.rows.length > 0) {
            const user = result.rows[0];
            console.log('Username:', user.username);
            console.log('Password match test (password123):', user.password === 'password123');
        }
        
        await pool.end();
    } catch (error) {
        console.log('✗ Database error:', error.message);
        await pool.end();
    }
}
testDB();
"

# Create simplified authentication test
echo ""
echo "=== CREATING SIMPLE AUTH TEST ==="
cat > simple-auth-test.js << 'SIMPLE_EOF'
const express = require('express');
const session = require('express-session');
const { Pool } = require('pg');

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
        console.log('[Simple Auth] Login attempt for:', req.body.username);
        
        const { username, password } = req.body;
        
        if (!username || !password) {
            console.log('[Simple Auth] Missing credentials');
            return res.status(400).json({ error: 'Missing credentials' });
        }
        
        console.log('[Simple Auth] Querying database for user:', username);
        const result = await pool.query('SELECT * FROM users WHERE username = $1', [username]);
        
        if (result.rows.length === 0) {
            console.log('[Simple Auth] User not found');
            return res.status(401).json({ error: 'User not found' });
        }
        
        const user = result.rows[0];
        console.log('[Simple Auth] User found:', user.username);
        console.log('[Simple Auth] Password comparison:', user.password, '===', password, ':', user.password === password);
        
        if (user.password !== password) {
            console.log('[Simple Auth] Invalid password');
            return res.status(401).json({ error: 'Invalid password' });
        }
        
        // Store user in session
        req.session.user = user;
        
        console.log('[Simple Auth] Login successful');
        res.json({ 
            success: true, 
            user: { 
                username: user.username, 
                role: user.role,
                email: user.email 
            } 
        });
        
    } catch (error) {
        console.error('[Simple Auth] Error:', error.message);
        console.error('[Simple Auth] Stack:', error.stack);
        res.status(500).json({ error: 'Authentication error: ' + error.message });
    }
});

app.get('/simple-me', (req, res) => {
    if (req.session.user) {
        res.json({ user: req.session.user });
    } else {
        res.status(401).json({ error: 'Not authenticated' });
    }
});

const port = 5002;
app.listen(port, '0.0.0.0', () => {
    console.log('[Simple Auth] Test server running on port', port);
});
SIMPLE_EOF

# Start simple test server
echo ""
echo "=== STARTING SIMPLE TEST SERVER ==="
node simple-auth-test.js &
SIMPLE_PID=$!
sleep 8

# Test simple authentication
echo ""
echo "=== TESTING SIMPLE AUTHENTICATION ==="
SIMPLE_RESULT=$(curl -s -X POST http://localhost:5002/simple-login \
    -H "Content-Type: application/json" \
    -d '{"username":"test.user","password":"password123"}')

echo "Simple auth result: $SIMPLE_RESULT"

# Test session endpoint
echo ""
echo "=== TESTING SIMPLE SESSION ==="
curl -s http://localhost:5002/simple-me

# Kill simple test server
kill $SIMPLE_PID 2>/dev/null
sleep 2
rm -f simple-auth-test.js

# Now test main production server
echo ""
echo ""
echo "=== TESTING MAIN PRODUCTION SERVER ==="
MAIN_RESULT=$(curl -s -X POST http://localhost:5000/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"username":"test.user","password":"password123"}')

echo "Main server result: $MAIN_RESULT"

# Get recent PM2 logs after our tests
echo ""
echo "=== RECENT PM2 LOGS AFTER TESTS ==="
pm2 logs servicedesk --lines 8

# Test HTTPS external access
echo ""
echo "=== TESTING EXTERNAL HTTPS ==="
HTTPS_RESULT=$(curl -k -s https://98.81.235.7/api/auth/login \
    -X POST \
    -H "Content-Type: application/json" \
    -d '{"username":"test.user","password":"password123"}')

echo "HTTPS result: $HTTPS_RESULT"

# Final analysis
echo ""
echo "=== ANALYSIS ==="
if echo "$SIMPLE_RESULT" | grep -q "success"; then
    echo "✓ Simple authentication server: WORKING"
else
    echo "✗ Simple authentication server: FAILED"
fi

if echo "$MAIN_RESULT" | grep -q "user"; then
    echo "✓ Main production server: WORKING"
    echo ""
    echo "SUCCESS! Authentication is now working on Ubuntu server"
    echo "Login at https://98.81.235.7 with test.user/password123"
else
    echo "✗ Main production server: FAILED"
    echo "Main server response: $MAIN_RESULT"
fi

EOF