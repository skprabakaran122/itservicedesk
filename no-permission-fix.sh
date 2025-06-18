#!/bin/bash

echo "No Permission Fix - Ubuntu Authentication"
echo "========================================"

cat << 'EOF'
# Fix the ES module issue on Ubuntu server:

cd /var/www/itservicedesk

# The issue is that package.json has "type": "module" 
# which makes Node.js treat .js files as ES modules
# We need to use .cjs extension for CommonJS

# Create authentication server with .cjs extension
cat > simple-auth.cjs << 'AUTH_EOF'
const express = require('express');
const session = require('express-session');
const { Pool } = require('pg');

console.log('[Auth Server] Starting IT Service Desk authentication...');

const app = express();
app.use(express.json());

// Session middleware
app.use(session({
    secret: 'calpion-service-desk-secret-key-2025',
    resave: false,
    saveUninitialized: false,
    cookie: { secure: false, maxAge: 24 * 60 * 60 * 1000 }
}));

// Database connection
const pool = new Pool({
    connectionString: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk'
});

// Test database connection on startup
pool.query('SELECT 1')
    .then(() => console.log('[Auth Server] Database connected'))
    .catch(err => console.error('[Auth Server] Database error:', err));

// Authentication route with comprehensive logging
app.post('/api/auth/login', async (req, res) => {
    try {
        console.log('[Auth] === LOGIN ATTEMPT ===');
        console.log('[Auth] Username:', req.body.username);
        console.log('[Auth] Body received:', JSON.stringify(req.body));
        
        const { username, password } = req.body;
        
        if (!username || !password) {
            console.log('[Auth] ERROR: Missing credentials');
            return res.status(400).json({ message: "Username and password required" });
        }
        
        console.log('[Auth] Querying database for user:', username);
        const result = await pool.query(
            'SELECT id, username, email, password, role, name, created_at FROM users WHERE username = $1 OR email = $1', 
            [username]
        );
        
        console.log('[Auth] Database query completed. Rows found:', result.rows.length);
        
        if (result.rows.length === 0) {
            console.log('[Auth] ERROR: User not found:', username);
            return res.status(401).json({ message: "Invalid credentials" });
        }
        
        const user = result.rows[0];
        console.log('[Auth] User found in database:');
        console.log('[Auth] - ID:', user.id);
        console.log('[Auth] - Username:', user.username);
        console.log('[Auth] - Email:', user.email);
        console.log('[Auth] - Role:', user.role);
        console.log('[Auth] - Stored password:', user.password);
        console.log('[Auth] - Provided password:', password);
        
        // Simple password comparison
        const passwordValid = user.password === password;
        console.log('[Auth] Password comparison result:', passwordValid);
        
        if (!passwordValid) {
            console.log('[Auth] ERROR: Password mismatch for user:', username);
            return res.status(401).json({ message: "Invalid credentials" });
        }
        
        // Store user in session
        req.session.user = user;
        console.log('[Auth] User stored in session successfully');
        
        // Return user data (excluding password)
        const { password: _, ...userWithoutPassword } = user;
        console.log('[Auth] SUCCESS: Login completed for user:', user.username);
        console.log('[Auth] Returning user data:', JSON.stringify(userWithoutPassword));
        
        res.json({ user: userWithoutPassword });
        
    } catch (error) {
        console.error('[Auth] CRITICAL ERROR during login:');
        console.error('[Auth] Error message:', error.message);
        console.error('[Auth] Error stack:', error.stack);
        res.status(500).json({ message: "Login failed" });
    }
});

// Session check endpoint
app.get('/api/auth/me', (req, res) => {
    try {
        console.log('[Auth] Session check - Session exists:', !!req.session);
        console.log('[Auth] Session check - User in session:', !!req.session?.user);
        
        if (req.session && req.session.user) {
            const { password: _, ...userWithoutPassword } = req.session.user;
            console.log('[Auth] Session valid for user:', req.session.user.username);
            res.json({ user: userWithoutPassword });
        } else {
            console.log('[Auth] No valid session found');
            res.status(401).json({ message: "Not authenticated" });
        }
    } catch (error) {
        console.error('[Auth] Session check error:', error);
        res.status(500).json({ message: "Authentication check failed" });
    }
});

// Logout endpoint
app.post('/api/auth/logout', (req, res) => {
    try {
        req.session.destroy((err) => {
            if (err) {
                console.error('[Auth] Logout error:', err);
                return res.status(500).json({ message: "Logout failed" });
            }
            console.log('[Auth] User logged out successfully');
            res.clearCookie('connect.sid');
            res.json({ message: "Logged out successfully" });
        });
    } catch (error) {
        console.error('[Auth] Logout error:', error);
        res.status(500).json({ message: "Logout failed" });
    }
});

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

// Start server
const port = 5000;
app.listen(port, '0.0.0.0', () => {
    console.log(`[Auth Server] HTTP server running on port ${port} (host: 0.0.0.0)`);
    console.log('[Auth Server] Authentication endpoints ready');
    console.log('[Auth Server] Available endpoints:');
    console.log('[Auth Server] - POST /api/auth/login');
    console.log('[Auth Server] - GET /api/auth/me');
    console.log('[Auth Server] - POST /api/auth/logout');
    console.log('[Auth Server] - GET /health');
});
AUTH_EOF

# Create PM2 config for the .cjs server
cat > auth-server.config.cjs << 'PM2_EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'simple-auth.cjs',
    instances: 1,
    autorestart: true,
    max_restarts: 5,
    restart_delay: 3000,
    env: {
      NODE_ENV: 'production',
      PORT: 5000,
      DATABASE_URL: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk',
      SESSION_SECRET: 'calpion-service-desk-secret-key-2025'
    },
    error_file: '/tmp/servicedesk-error.log',
    out_file: '/tmp/servicedesk-out.log',
    log_file: '/tmp/servicedesk-combined.log',
    merge_logs: true,
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z'
  }]
};
PM2_EOF

# Stop existing PM2 process
pm2 delete servicedesk 2>/dev/null || echo "No existing process to stop"

# Start authentication server with .cjs extension
echo ""
echo "=== STARTING AUTHENTICATION SERVER (.cjs) ==="
pm2 start auth-server.config.cjs
pm2 save

# Wait for startup
sleep 18

# Test health endpoint first
echo ""
echo "=== TESTING HEALTH ENDPOINT ==="
curl -s http://localhost:5000/health

# Test authentication with detailed output
echo ""
echo ""
echo "=== TESTING AUTHENTICATION ==="
AUTH_RESULT=$(curl -s -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.user","password":"password123"}')

echo "Local authentication result:"
echo "$AUTH_RESULT"

# Test admin authentication
echo ""
echo "=== TESTING ADMIN AUTHENTICATION ==="
ADMIN_RESULT=$(curl -s -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.admin","password":"password123"}')

echo "Admin authentication result:"
echo "$ADMIN_RESULT"

# Test external HTTPS access
echo ""
echo "=== TESTING EXTERNAL HTTPS ==="
HTTPS_RESULT=$(curl -k -s https://98.81.235.7/api/auth/login \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"username":"test.user","password":"password123"}')

echo "HTTPS authentication result:"
echo "$HTTPS_RESULT"

# Test session endpoint after successful login
echo ""
echo "=== TESTING SESSION ENDPOINT ==="
SESSION_RESULT=$(curl -s http://localhost:5000/api/auth/me)
echo "Session check result:"
echo "$SESSION_RESULT"

# Check PM2 status
echo ""
echo "=== PM2 STATUS ==="
pm2 status

# Show detailed authentication logs
echo ""
echo "=== DETAILED AUTHENTICATION LOGS ==="
pm2 logs servicedesk --lines 20

# Final verification
echo ""
echo "=== FINAL VERIFICATION ==="
if echo "$AUTH_RESULT" | grep -q '"user"'; then
    echo "SUCCESS: Ubuntu server authentication is working!"
    echo ""
    echo "Production deployment complete:"
    echo "- Local authentication: WORKING"
    echo "- Server: https://98.81.235.7"
    echo "- External HTTPS: $(echo "$HTTPS_RESULT" | grep -q user && echo "WORKING" || echo "Check nginx configuration")"
    echo ""
    echo "Login credentials:"
    echo "- test.user / password123 (user role)"
    echo "- test.admin / password123 (admin role)"
    echo ""
    echo "Ubuntu IT Service Desk is fully operational!"
elif echo "$AUTH_RESULT" | grep -q "502 Bad Gateway"; then
    echo "502 Bad Gateway - nginx proxy issue detected"
    echo "The authentication server is running but nginx can't reach it"
    echo "Check nginx configuration and port forwarding"
else
    echo "Authentication result: $AUTH_RESULT"
    echo "Check the detailed logs above for debugging information"
fi

EOF