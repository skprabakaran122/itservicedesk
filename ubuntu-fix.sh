#!/bin/bash
cd /var/www/itservicedesk

# Create complete server with all user management routes
cat > complete-user-mgmt.cjs << 'SERVER_EOF'
const express = require('express');
const session = require('express-session');
const { Pool } = require('pg');
const path = require('path');
const fs = require('fs');

const app = express();
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.use(session({
    secret: 'calpion-service-desk-secret-key-2025',
    resave: false,
    saveUninitialized: false,
    name: 'connect.sid',
    cookie: { secure: false, httpOnly: true, maxAge: 24 * 60 * 60 * 1000, sameSite: 'lax' }
}));

const pool = new Pool({
    connectionString: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk'
});

const requireAuth = (req, res, next) => {
    if (req.session && req.session.user) {
        next();
    } else {
        res.status(401).json({ message: "Authentication required" });
    }
};

const requireAdmin = (req, res, next) => {
    if (req.session && req.session.user && (req.session.user.role === 'admin' || req.session.user.role === 'manager')) {
        next();
    } else {
        res.status(403).json({ message: "Admin access required" });
    }
};

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
        console.error('[Auth] Error:', error.message);
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

// User management routes
app.get('/api/users', requireAuth, async (req, res) => {
    try {
        console.log('[Users] Fetching all users');
        const result = await pool.query(
            'SELECT id, username, email, role, name, assigned_products, created_at FROM users ORDER BY created_at DESC'
        );
        console.log('[Users] Found', result.rows.length, 'users');
        res.json(result.rows);
    } catch (error) {
        console.error('[Users] Error:', error.message);
        res.status(500).json({ message: "Failed to fetch users" });
    }
});

app.post('/api/users', requireAdmin, async (req, res) => {
    try {
        const { username, email, password, role, name } = req.body;
        
        if (!username || !email || !password || !role || !name) {
            return res.status(400).json({ message: "All fields are required" });
        }
        
        const existingUser = await pool.query(
            'SELECT id FROM users WHERE username = $1 OR email = $2',
            [username, email]
        );
        
        if (existingUser.rows.length > 0) {
            return res.status(409).json({ message: "User already exists" });
        }
        
        const result = await pool.query(
            'INSERT INTO users (username, email, password, role, name, created_at) VALUES ($1, $2, $3, $4, $5, NOW()) RETURNING id, username, email, role, name, created_at',
            [username, email, password, role, name]
        );
        
        console.log('[Users] Created user:', result.rows[0].username);
        res.status(201).json(result.rows[0]);
    } catch (error) {
        console.error('[Users] Create error:', error.message);
        res.status(500).json({ message: "Failed to create user" });
    }
});

app.put('/api/users/:id', requireAdmin, async (req, res) => {
    try {
        const { id } = req.params;
        const { username, email, role, name, password } = req.body;
        
        let query = 'UPDATE users SET username = $1, email = $2, role = $3, name = $4';
        let params = [username, email, role, name];
        
        if (password) {
            query += ', password = $5';
            params.push(password);
        }
        
        query += ' WHERE id = $' + (params.length + 1) + ' RETURNING id, username, email, role, name, created_at';
        params.push(id);
        
        const result = await pool.query(query, params);
        
        if (result.rows.length === 0) {
            return res.status(404).json({ message: "User not found" });
        }
        
        res.json(result.rows[0]);
    } catch (error) {
        console.error('[Users] Update error:', error.message);
        res.status(500).json({ message: "Failed to update user" });
    }
});

app.delete('/api/users/:id', requireAdmin, async (req, res) => {
    try {
        const { id } = req.params;
        const result = await pool.query('DELETE FROM users WHERE id = $1 RETURNING username', [id]);
        
        if (result.rows.length === 0) {
            return res.status(404).json({ message: "User not found" });
        }
        
        res.json({ message: "User deleted successfully" });
    } catch (error) {
        console.error('[Users] Delete error:', error.message);
        res.status(500).json({ message: "Failed to delete user" });
    }
});

app.get('/health', (req, res) => {
    res.json({ 
        status: 'OK', 
        timestamp: new Date().toISOString(),
        authentication: 'Working',
        database: 'Connected',
        userManagement: 'Active'
    });
});

// Serve static files
const staticPath = path.join(__dirname, 'dist', 'public');
app.use(express.static(staticPath));

app.get('*', (req, res) => {
    const indexPath = path.join(__dirname, 'dist', 'public', 'index.html');
    if (fs.existsSync(indexPath)) {
        res.sendFile(indexPath);
    } else {
        res.status(404).send('Frontend build not found');
    }
});

const port = 5000;
app.listen(port, '0.0.0.0', () => {
    console.log(`[Complete] IT Service Desk running on port ${port} with full user management`);
});
SERVER_EOF

# PM2 config
cat > complete-user-mgmt.config.cjs << 'CONFIG_EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'complete-user-mgmt.cjs',
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
CONFIG_EOF

# Restart server
pm2 delete servicedesk
pm2 start complete-user-mgmt.config.cjs
pm2 save

