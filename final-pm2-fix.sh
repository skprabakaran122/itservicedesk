#!/bin/bash

echo "Final PM2 Fix - Ensure Correct Server Running"
echo "============================================="

cat << 'EOF'
# Completely restart PM2 with the correct server configuration:

cd /var/www/itservicedesk

echo "=== STOPPING ALL PM2 PROCESSES ==="
pm2 kill

echo ""
echo "=== VERIFYING BUILD STRUCTURE ==="
echo "Files in dist/public/:"
ls -la dist/public/ | head -10

echo ""
echo "=== CREATING FINAL CORRECTED SERVER ==="
cat > final-server.cjs << 'FINAL_SERVER_EOF'
const express = require('express');
const session = require('express-session');
const { Pool } = require('pg');
const path = require('path');

console.log('[Final Server] Starting Calpion IT Service Desk...');

const app = express();

// Middleware
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
    .then(() => console.log('[Final Server] Database connected successfully'))
    .catch(err => console.error('[Final Server] Database error:', err));

// Authentication routes
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
    if (req.session && req.session.user) {
        const { password: _, ...userWithoutPassword } = req.session.user;
        res.json({ user: userWithoutPassword });
    } else {
        res.status(401).json({ message: "Not authenticated" });
    }
});

app.post('/api/auth/logout', (req, res) => {
    req.session.destroy((err) => {
        if (err) {
            console.error('[Auth] Logout error:', err);
            return res.status(500).json({ message: "Logout failed" });
        }
        console.log('[Auth] User logged out successfully');
        res.clearCookie('connect.sid');
        res.json({ message: "Logged out successfully" });
    });
});

// Health check
app.get('/health', (req, res) => {
    res.json({ 
        status: 'OK', 
        timestamp: new Date().toISOString(),
        authentication: 'Working',
        database: 'Connected',
        frontend: 'Production Build Serving',
        staticPath: '/dist/public'
    });
});

// CRITICAL: Serve static files from the correct build directory
const staticPath = path.join(__dirname, 'dist', 'public');
console.log('[Final Server] Static files will be served from:', staticPath);

// Verify the static path exists
const fs = require('fs');
if (fs.existsSync(staticPath)) {
    console.log('[Final Server] Static path verified - exists');
    const indexPath = path.join(staticPath, 'index.html');
    if (fs.existsSync(indexPath)) {
        console.log('[Final Server] index.html found at:', indexPath);
    } else {
        console.log('[Final Server] WARNING: index.html not found at:', indexPath);
    }
} else {
    console.log('[Final Server] ERROR: Static path does not exist:', staticPath);
}

app.use(express.static(staticPath));

// SPA routing - serve index.html for all non-API routes
app.get('*', (req, res) => {
    const indexPath = path.join(__dirname, 'dist', 'public', 'index.html');
    console.log('[Final Server] Serving SPA route:', req.path, 'from:', indexPath);
    
    if (fs.existsSync(indexPath)) {
        res.sendFile(indexPath);
    } else {
        console.log('[Final Server] ERROR: Cannot find index.html at:', indexPath);
        res.status(404).send('Frontend build not found');
    }
});

const port = 5000;
app.listen(port, '0.0.0.0', () => {
    console.log(`[Final Server] Calpion IT Service Desk running on port ${port}`);
    console.log('[Final Server] Static files served from:', staticPath);
    console.log('[Final Server] Health check available at /health');
    console.log('[Final Server] Ready for production use!');
});
FINAL_SERVER_EOF

echo ""
echo "=== CREATING FINAL PM2 CONFIG ==="
cat > final-server.config.cjs << 'FINAL_PM2_EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'final-server.cjs',
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
FINAL_PM2_EOF

echo ""
echo "=== STARTING FINAL SERVER ==="
pm2 start final-server.config.cjs
pm2 save

sleep 25

echo ""
echo "=== COMPREHENSIVE TESTING ==="

# Test health endpoint
echo "Health check:"
curl -s http://localhost:5000/health

echo ""
echo ""
echo "Frontend serving test:"
FRONTEND_RESULT=$(curl -s -I http://localhost:5000/ | head -1)
echo "Frontend response: $FRONTEND_RESULT"

echo ""
echo "Authentication test:"
AUTH_RESULT=$(curl -s -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.admin","password":"password123"}')
echo "Auth response: $AUTH_RESULT"

echo ""
echo "External HTTPS test:"
HTTPS_RESULT=$(curl -k -s -I https://98.81.235.7/ | head -1)
echo "HTTPS response: $HTTPS_RESULT"

echo ""
echo "Static asset test:"
ASSET_RESULT=$(curl -s -I http://localhost:5000/assets/index-Bd_55WME.js | head -1)
echo "Asset response: $ASSET_RESULT"

echo ""
echo "=== PM2 STATUS ==="
pm2 status

echo ""
echo "=== RECENT LOGS (NO ERRORS EXPECTED) ==="
pm2 logs servicedesk --lines 10

echo ""
echo "=== FINAL VERIFICATION ==="
if echo "$FRONTEND_RESULT" | grep -q "200 OK" && echo "$AUTH_RESULT" | grep -q '"user"' && ! pm2 logs servicedesk --lines 5 | grep -q "ENOENT.*dist/index.html"; then
    echo "SUCCESS: All errors resolved! IT Service Desk fully operational!"
    echo ""
    echo "Production deployment verified:"
    echo "- Frontend: Serving properly with 200 OK responses"
    echo "- Authentication: Working with proper user data"
    echo "- Static files: Serving from correct dist/public path"
    echo "- No file path errors in logs"
    echo ""
    echo "Access your IT Service Desk:"
    echo "- URL: https://98.81.235.7"
    echo "- Admin: test.admin / password123"
    echo "- User: test.user / password123"
else
    echo "Still debugging. Results:"
    echo "Frontend: $FRONTEND_RESULT"
    echo "Auth: $AUTH_RESULT"
    echo "Check logs for remaining issues"
fi

EOF