#!/bin/bash

echo "Direct Authentication Fix - Ubuntu Server"
echo "======================================="

cat << 'EOF'
# Direct fix for Ubuntu server authentication logic:

cd /var/www/itservicedesk

# The issue is identified: Database works, but production authentication logic fails
echo "=== DIAGNOSIS CONFIRMED ==="
echo "✓ Database connection: Working"
echo "✓ User data: Available (test.user/password123)"
echo "✓ Password validation: Correct"
echo "✓ Dependencies: All loaded"
echo "❌ Production authentication endpoint: Has logic error"

# Clear PM2 logs for fresh debugging
pm2 flush

# Test current production authentication and capture logs
echo ""
echo "=== TESTING PRODUCTION SERVER WITH FRESH LOGS ==="
curl -s -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.user","password":"password123"}' \
  -w "\nHTTP Code: %{http_code}\n"

# Wait for logs to populate
sleep 5

# Get detailed PM2 logs showing the authentication error
echo ""
echo "=== FRESH PM2 LOGS SHOWING AUTHENTICATION ERROR ==="
pm2 logs servicedesk --lines 15 --timestamp

# Check if it's a session middleware issue
echo ""
echo "=== TESTING SESSION ENDPOINT ==="
curl -s http://localhost:5000/api/auth/me -w "\nHTTP Code: %{http_code}\n"

# Create working authentication test using proper CommonJS format
echo ""
echo "=== CREATING WORKING AUTHENTICATION TEST ==="
cat > working-auth.cjs << 'WORKING_EOF'
const express = require('express');
const { Pool } = require('pg');
const session = require('express-session');

console.log('[Working Test] Starting authentication test...');

const app = express();
app.use(express.json());

// Session configuration matching production
app.use(session({
    secret: 'calpion-service-desk-secret-key-2025',
    resave: false,
    saveUninitialized: false,
    cookie: { secure: false, maxAge: 24 * 60 * 60 * 1000 }
}));

const pool = new Pool({
    connectionString: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk'
});

app.post('/working-login', async (req, res) => {
    console.log('[Working Test] Login attempt for:', req.body.username);
    
    try {
        const { username, password } = req.body;
        
        if (!username || !password) {
            console.log('[Working Test] Missing credentials');
            return res.status(400).json({ message: "Username and password required" });
        }
        
        console.log('[Working Test] Querying database...');
        const result = await pool.query('SELECT * FROM users WHERE username = $1 OR email = $1', [username]);
        
        if (result.rows.length === 0) {
            console.log('[Working Test] User not found in database');
            return res.status(401).json({ message: "Invalid credentials" });
        }
        
        const user = result.rows[0];
        console.log('[Working Test] User found:', user.username);
        console.log('[Working Test] Stored password:', user.password);
        console.log('[Working Test] Provided password:', password);
        console.log('[Working Test] Password match:', user.password === password);
        
        // Simple password comparison (production uses plain text)
        if (user.password !== password) {
            console.log('[Working Test] Password mismatch');
            return res.status(401).json({ message: "Invalid credentials" });
        }
        
        // Store user in session
        req.session.user = user;
        console.log('[Working Test] User stored in session');
        
        // Return user data (excluding password)
        const { password: _, ...userWithoutPassword } = user;
        
        console.log('[Working Test] Authentication successful for:', user.username);
        res.json({ user: userWithoutPassword });
        
    } catch (error) {
        console.error('[Working Test] Authentication error:', error.message);
        console.error('[Working Test] Stack trace:', error.stack);
        res.status(500).json({ message: "Login failed" });
    }
});

app.get('/working-me', (req, res) => {
    if (req.session && req.session.user) {
        const { password: _, ...userWithoutPassword } = req.session.user;
        res.json({ user: userWithoutPassword });
    } else {
        res.status(401).json({ message: "Not authenticated" });
    }
});

const port = 5006;
app.listen(port, '0.0.0.0', () => {
    console.log('[Working Test] Server running on port', port);
});
WORKING_EOF

# Start working authentication test
echo ""
echo "=== STARTING WORKING AUTHENTICATION TEST ==="
node working-auth.cjs &
WORKING_PID=$!
sleep 8

# Test working authentication
echo ""
echo "=== TESTING WORKING AUTHENTICATION ==="
WORKING_RESULT=$(curl -s -X POST http://localhost:5006/working-login \
    -H "Content-Type: application/json" \
    -d '{"username":"test.user","password":"password123"}')

echo "Working auth result: $WORKING_RESULT"

# Test working session endpoint
echo ""
echo "=== TESTING WORKING SESSION ==="
curl -s http://localhost:5006/working-me

# Kill working test server
kill $WORKING_PID 2>/dev/null
sleep 2
rm -f working-auth.cjs

# Final comparison
echo ""
echo ""
echo "=== FINAL DIAGNOSIS ==="
if echo "$WORKING_RESULT" | grep -q "user"; then
    echo "✓ Working authentication test: SUCCESS"
    echo "✓ Database connectivity: Confirmed working"
    echo "✓ User lookup: Confirmed working"
    echo "✓ Password validation: Confirmed working"
    echo "✓ Session management: Confirmed working"
    echo ""
    echo "CONCLUSION: The authentication logic itself works perfectly."
    echo "ISSUE: Production server build has a bug in the authentication route."
    echo ""
    echo "SOLUTION NEEDED: Fix production server authentication route or rebuild with correct logic."
else
    echo "✗ Working authentication test: FAILED"
    echo "ISSUE: Deeper system problem with authentication components"
fi

# Test production server one more time
echo ""
echo "=== FINAL PRODUCTION SERVER TEST ==="
FINAL_PROD=$(curl -s -X POST http://localhost:5000/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"username":"test.user","password":"password123"}')

echo "Final production result: $FINAL_PROD"

if echo "$FINAL_PROD" | grep -q "user"; then
    echo ""
    echo "SUCCESS! Production authentication is now working!"
    echo "Ubuntu server ready at: https://98.81.235.7"
    echo "Login credentials: test.user/password123"
else
    echo ""
    echo "Production authentication still needs the route logic fixed."
    echo "All components work individually - issue is in production build authentication route."
fi

# Show PM2 status
echo ""
echo "=== CURRENT PM2 STATUS ==="
pm2 status

EOF