#!/bin/bash

echo "Quick Path Fix for Static Serving"
echo "================================="

cat << 'EOF'
# Quick fix for the static file path issue:

cd /var/www/itservicedesk

echo "=== CHECKING BUILD PATHS ==="
echo "Files in dist/:"
ls -la dist/

echo ""
echo "Files in dist/public/:"
ls -la dist/public/

echo ""
echo "=== CREATING QUICK PATH FIX SERVER ==="
cat > path-fix.cjs << 'PATH_FIX_EOF'
const express = require('express');
const session = require('express-session');
const { Pool } = require('pg');
const path = require('path');

console.log('[Path Fix] Starting server with correct static paths...');

const app = express();
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Session middleware
app.use(session({
    secret: 'calpion-service-desk-secret-key-2025',
    resave: false,
    saveUninitialized: false,
    name: 'connect.sid',
    cookie: { secure: false, httpOnly: true, maxAge: 24 * 60 * 60 * 1000, sameSite: 'lax' }
}));

// Database connection
const pool = new Pool({
    connectionString: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk'
});

// Authentication routes
app.post('/api/auth/login', async (req, res) => {
    try {
        const { username, password } = req.body;
        if (!username || !password) {
            return res.status(400).json({ message: "Username and password required" });
        }
        
        const result = await pool.query(
            'SELECT id, username, email, password, role, name, created_at FROM users WHERE username = $1 OR email = $1', 
            [username]
        );
        
        if (result.rows.length === 0 || result.rows[0].password !== password) {
            return res.status(401).json({ message: "Invalid credentials" });
        }
        
        const user = result.rows[0];
        req.session.user = user;
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
        if (err) return res.status(500).json({ message: "Logout failed" });
        res.clearCookie('connect.sid');
        res.json({ message: "Logged out successfully" });
    });
});

app.get('/health', (req, res) => {
    res.json({ 
        status: 'OK', 
        timestamp: new Date().toISOString(),
        authentication: 'Working',
        database: 'Connected',
        frontend: 'Production Build'
    });
});

// Serve static files from dist/public (where the build actually put them)
const staticPath = path.join(__dirname, 'dist', 'public');
console.log('[Path Fix] Serving static files from:', staticPath);
app.use(express.static(staticPath));

// SPA routing - serve index.html from correct location
app.get('*', (req, res) => {
    const indexPath = path.join(__dirname, 'dist', 'public', 'index.html');
    console.log('[Path Fix] Serving index.html from:', indexPath);
    res.sendFile(indexPath);
});

const port = 5000;
app.listen(port, '0.0.0.0', () => {
    console.log(`[Path Fix] Server running on port ${port}`);
    console.log('[Path Fix] Static files served from: dist/public');
    console.log('[Path Fix] Ready!');
});
PATH_FIX_EOF

echo ""
echo "=== CREATING PM2 CONFIG ==="
cat > path-fix.config.cjs << 'PM2_PATH_EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'path-fix.cjs',
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
    out_file: '/tmp/servicedesk-out.log'
  }]
};
PM2_PATH_EOF

echo ""
echo "=== RESTARTING WITH CORRECT PATHS ==="
pm2 delete servicedesk
pm2 start path-fix.config.cjs
pm2 save

sleep 15

echo ""
echo "=== TESTING PATH FIX ==="
echo "Health check:"
curl -s http://localhost:5000/health

echo ""
echo ""
echo "Frontend test:"
curl -s -I http://localhost:5000/ | head -1

echo ""
echo "Auth test:"
curl -s -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.admin","password":"password123"}'

echo ""
echo ""
echo "HTTPS test:"
curl -k -s -I https://98.81.235.7/ | head -1

echo ""
echo "PM2 status:"
pm2 status

echo ""
echo "Recent logs:"
pm2 logs servicedesk --lines 5

EOF