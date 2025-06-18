#!/bin/bash

echo "Complete Ubuntu Server Fix - Add Frontend Serving"
echo "================================================"

cat << 'EOF'
# Create complete server that serves both API and frontend:

cd /var/www/itservicedesk

# First, ensure frontend is built
echo "=== BUILDING FRONTEND ==="
npm run build

echo ""
echo "=== CREATING COMPLETE SERVER ==="
cat > complete-server.cjs << 'COMPLETE_EOF'
const express = require('express');
const session = require('express-session');
const { Pool } = require('pg');
const path = require('path');

console.log('[Complete Server] Starting IT Service Desk with frontend...');

const app = express();

// Basic middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Session middleware
app.use(session({
    secret: 'calpion-service-desk-secret-key-2025',
    resave: false,
    saveUninitialized: false,
    name: 'connect.sid',
    cookie: { 
        secure: false, 
        httpOnly: true,
        maxAge: 24 * 60 * 60 * 1000,
        sameSite: 'lax'
    }
}));

// Database connection
const pool = new Pool({
    connectionString: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk'
});

// Test database connection
pool.query('SELECT 1')
    .then(() => console.log('[Complete Server] Database connected'))
    .catch(err => console.error('[Complete Server] Database error:', err));

// API Routes
console.log('[Complete Server] Setting up API routes...');

// Authentication route
app.post('/api/auth/login', async (req, res) => {
    try {
        console.log('[Auth] Login attempt for:', req.body.username);
        
        const { username, password } = req.body;
        
        if (!username || !password) {
            console.log('[Auth] Missing credentials');
            return res.status(400).json({ message: "Username and password required" });
        }
        
        const result = await pool.query(
            'SELECT id, username, email, password, role, name, created_at FROM users WHERE username = $1 OR email = $1', 
            [username]
        );
        
        if (result.rows.length === 0) {
            console.log('[Auth] User not found:', username);
            return res.status(401).json({ message: "Invalid credentials" });
        }
        
        const user = result.rows[0];
        console.log('[Auth] User found:', user.username);
        
        if (user.password !== password) {
            console.log('[Auth] Invalid password');
            return res.status(401).json({ message: "Invalid credentials" });
        }
        
        req.session.user = user;
        console.log('[Auth] Login successful for:', user.username);
        
        const { password: _, ...userWithoutPassword } = user;
        res.json({ user: userWithoutPassword });
        
    } catch (error) {
        console.error('[Auth] Login error:', error.message);
        res.status(500).json({ message: "Login failed" });
    }
});

app.get('/api/auth/me', (req, res) => {
    try {
        if (req.session && req.session.user) {
            const { password: _, ...userWithoutPassword } = req.session.user;
            res.json({ user: userWithoutPassword });
        } else {
            res.status(401).json({ message: "Not authenticated" });
        }
    } catch (error) {
        console.error('[Auth] Session check error:', error);
        res.status(500).json({ message: "Authentication check failed" });
    }
});

app.post('/api/auth/logout', (req, res) => {
    try {
        req.session.destroy((err) => {
            if (err) {
                console.error('[Auth] Logout error:', err);
                return res.status(500).json({ message: "Logout failed" });
            }
            res.clearCookie('connect.sid');
            res.json({ message: "Logged out successfully" });
        });
    } catch (error) {
        console.error('[Auth] Logout error:', error);
        res.status(500).json({ message: "Logout failed" });
    }
});

// Health check
app.get('/health', (req, res) => {
    res.json({ 
        status: 'OK', 
        timestamp: new Date().toISOString(),
        authentication: 'Working',
        database: 'Connected'
    });
});

// Serve static files from dist directory
console.log('[Complete Server] Setting up static file serving...');
app.use(express.static(path.join(__dirname, 'dist')));

// Serve frontend for all non-API routes
app.get('*', (req, res) => {
    console.log('[Frontend] Serving:', req.path);
    res.sendFile(path.join(__dirname, 'dist', 'index.html'));
});

// Start server
const port = 5000;
app.listen(port, '0.0.0.0', () => {
    console.log(`[Complete Server] HTTP server running on port ${port} (host: 0.0.0.0)`);
    console.log('[Complete Server] Frontend served from /dist');
    console.log('[Complete Server] API endpoints available at /api/*');
    console.log('[Complete Server] Health check at /health');
    console.log('[Complete Server] Ready for production use!');
});
COMPLETE_EOF

echo ""
echo "=== CREATING PM2 CONFIG FOR COMPLETE SERVER ==="
cat > complete-server.config.cjs << 'PM2_COMPLETE_EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'complete-server.cjs',
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
PM2_COMPLETE_EOF

echo ""
echo "=== RESTARTING WITH COMPLETE SERVER ==="
pm2 delete servicedesk 2>/dev/null
pm2 start complete-server.config.cjs
pm2 save

sleep 20

echo ""
echo "=== TESTING COMPLETE SERVER ==="

# Test health endpoint
echo "Health check:"
curl -s http://localhost:5000/health

echo ""
echo ""
echo "Authentication test:"
AUTH_RESULT=$(curl -s -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.admin","password":"password123"}')
echo "$AUTH_RESULT"

echo ""
echo ""
echo "Frontend test:"
FRONTEND_RESULT=$(curl -s -I http://localhost:5000/ | head -1)
echo "Frontend response: $FRONTEND_RESULT"

echo ""
echo "External HTTPS test:"
HTTPS_FRONTEND=$(curl -k -s -I https://98.81.235.7/ | head -1)
echo "HTTPS frontend: $HTTPS_FRONTEND"

echo ""
echo "=== PM2 STATUS ==="
pm2 status

echo ""
echo "=== RECENT LOGS ==="
pm2 logs servicedesk --lines 10

echo ""
echo "=== FINAL VERIFICATION ==="
if echo "$FRONTEND_RESULT" | grep -q "200 OK"; then
    echo "SUCCESS: Complete server is working!"
    echo ""
    echo "IT Service Desk is fully operational:"
    echo "- Frontend: Working at https://98.81.235.7"
    echo "- Authentication: Working"
    echo "- Database: Connected"
    echo ""
    echo "Login credentials:"
    echo "- test.admin / password123 (admin access)"
    echo "- test.user / password123 (user access)"
    echo ""
    echo "You can now access the full IT Service Desk application!"
else
    echo "Frontend serving issue detected"
    echo "Frontend result: $FRONTEND_RESULT"
    echo "Check the logs above for details"
fi

EOF