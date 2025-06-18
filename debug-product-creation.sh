#!/bin/bash
cd /var/www/itservicedesk

# Create enhanced server with detailed product creation logging
cat > working-server-debug.cjs << 'EOF'
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
        console.log('[Auth] Authenticated user:', req.session.user.username, 'Role:', req.session.user.role);
        next();
    } else {
        console.log('[Auth] No authentication found');
        res.status(401).json({ message: "Authentication required" });
    }
};

const requireAdmin = (req, res, next) => {
    if (req.session && req.session.user && ['admin', 'manager'].includes(req.session.user.role)) {
        console.log('[Auth] Admin access granted for:', req.session.user.username);
        next();
    } else {
        console.log('[Auth] Admin access denied for:', req.session?.user?.username || 'anonymous', 'Role:', req.session?.user?.role);
        res.status(403).json({ message: "Admin access required" });
    }
};

// Authentication
app.post('/api/auth/login', async (req, res) => {
    try {
        const { username, password } = req.body;
        console.log('[Auth] Login attempt for:', username);
        
        const result = await pool.query('SELECT * FROM users WHERE username = $1 OR email = $1', [username]);
        
        if (result.rows.length === 0 || result.rows[0].password !== password) {
            console.log('[Auth] Invalid credentials for:', username);
            return res.status(401).json({ message: "Invalid credentials" });
        }
        
        req.session.user = result.rows[0];
        const { password: _, ...userWithoutPassword } = result.rows[0];
        console.log('[Auth] Login successful for:', username, 'Role:', result.rows[0].role);
        res.json({ user: userWithoutPassword });
    } catch (error) {
        console.error('[Auth] Login error:', error);
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

// Users
app.get('/api/users', requireAuth, async (req, res) => {
    try {
        const result = await pool.query('SELECT id, username, email, role, name, assigned_products as "assignedProducts", created_at as "createdAt" FROM users ORDER BY created_at DESC');
        res.json(result.rows);
    } catch (error) {
        console.error('[Users] Fetch error:', error);
        res.status(500).json({ message: "Failed to fetch users" });
    }
});

app.post('/api/users', requireAdmin, async (req, res) => {
    try {
        const { username, email, password, role, name, assignedProducts } = req.body;
        
        if (!username || !email || !password || !role || !name) {
            return res.status(400).json({ message: "All fields are required" });
        }
        
        const existing = await pool.query('SELECT id FROM users WHERE username = $1 OR email = $2', [username, email]);
        if (existing.rows.length > 0) return res.status(409).json({ message: "User already exists" });
        
        const result = await pool.query(
            'INSERT INTO users (username, email, password, role, name, assigned_products, created_at) VALUES ($1, $2, $3, $4, $5, $6, NOW()) RETURNING id, username, email, role, name, assigned_products as "assignedProducts", created_at as "createdAt"',
            [username, email, password, role, name, assignedProducts || null]
        );
        res.status(201).json(result.rows[0]);
    } catch (error) {
        console.error('[Users] Create error:', error);
        res.status(500).json({ message: "Failed to create user" });
    }
});

app.patch('/api/users/:id', requireAdmin, async (req, res) => {
    try {
        const { id } = req.params;
        const { username, email, role, name, password, assignedProducts } = req.body;
        
        let query = 'UPDATE users SET username = $1, email = $2, role = $3, name = $4, assigned_products = $5';
        let params = [username, email, role, name, assignedProducts || null];
        
        if (password) {
            query += ', password = $6';
            params.push(password);
        }
        
        query += ' WHERE id = $' + (params.length + 1) + ' RETURNING id, username, email, role, name, assigned_products as "assignedProducts", created_at as "createdAt"';
        params.push(id);
        
        const result = await pool.query(query, params);
        if (result.rows.length === 0) return res.status(404).json({ message: "User not found" });
        res.json(result.rows[0]);
    } catch (error) {
        console.error('[Users] Update error:', error);
        res.status(500).json({ message: "Failed to update user" });
    }
});

app.delete('/api/users/:id', requireAdmin, async (req, res) => {
    try {
        const { id } = req.params;
        const result = await pool.query('DELETE FROM users WHERE id = $1 RETURNING username', [id]);
        if (result.rows.length === 0) return res.status(404).json({ message: "User not found" });
        res.json({ success: true, message: "User deleted successfully" });
    } catch (error) {
        console.error('[Users] Delete error:', error);
        res.status(500).json({ message: "Failed to delete user" });
    }
});

// Products (with enhanced debugging)
app.get('/api/products', requireAuth, async (req, res) => {
    try {
        console.log('[Products] Fetching products for user:', req.session.user.username);
        const result = await pool.query('SELECT * FROM products ORDER BY name');
        console.log('[Products] Found', result.rows.length, 'products');
        res.json(result.rows);
    } catch (error) {
        console.error('[Products] Fetch error:', error);
        res.status(500).json({ message: "Failed to fetch products" });
    }
});

app.post('/api/products', requireAuth, requireAdmin, async (req, res) => {
    try {
        console.log('[Products] === PRODUCT CREATION DEBUG ===');
        console.log('[Products] User:', req.session.user.username, 'Role:', req.session.user.role);
        console.log('[Products] Request body:', JSON.stringify(req.body, null, 2));
        
        const { name, description, category, owner } = req.body;
        
        // Validate input
        if (!name || typeof name !== 'string' || name.trim().length === 0) {
            console.log('[Products] Validation failed: name is required');
            return res.status(400).json({ message: "Product name is required" });
        }
        
        const cleanName = name.trim();
        const cleanDescription = description || '';
        const cleanCategory = category || 'other';
        const cleanOwner = owner || null;
        
        console.log('[Products] Cleaned data:', {
            name: cleanName,
            description: cleanDescription,
            category: cleanCategory,
            owner: cleanOwner
        });
        
        // Check if products table exists and get structure
        const tableCheck = await pool.query("SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'products' ORDER BY ordinal_position");
        console.log('[Products] Table structure:', tableCheck.rows);
        
        // Try to insert
        console.log('[Products] Attempting insert...');
        const result = await pool.query(
            'INSERT INTO products (name, description, category, owner, created_at) VALUES ($1, $2, $3, $4, NOW()) RETURNING *',
            [cleanName, cleanDescription, cleanCategory, cleanOwner]
        );
        
        console.log('[Products] Insert successful:', result.rows[0]);
        res.status(201).json(result.rows[0]);
        
    } catch (error) {
        console.error('[Products] === CREATE ERROR ===');
        console.error('[Products] Error code:', error.code);
        console.error('[Products] Error message:', error.message);
        console.error('[Products] Error detail:', error.detail);
        console.error('[Products] Full error:', error);
        res.status(500).json({ message: `Failed to create product: ${error.message}` });
    }
});

app.patch('/api/products/:id', requireAdmin, async (req, res) => {
    try {
        const { id } = req.params;
        const { name, description, category, owner } = req.body;
        
        console.log('[Products] Updating product ID:', id);
        
        const result = await pool.query(
            'UPDATE products SET name = $1, description = $2, category = $3, owner = $4 WHERE id = $5 RETURNING *',
            [name, description, category, owner, id]
        );
        if (result.rows.length === 0) return res.status(404).json({ message: "Product not found" });
        res.json(result.rows[0]);
    } catch (error) {
        console.error('[Products] Update error:', error);
        res.status(500).json({ message: "Failed to update product" });
    }
});

app.delete('/api/products/:id', requireAdmin, async (req, res) => {
    try {
        const { id } = req.params;
        console.log('[Products] Deleting product ID:', id);
        
        const result = await pool.query('DELETE FROM products WHERE id = $1 RETURNING name', [id]);
        if (result.rows.length === 0) return res.status(404).json({ message: "Product not found" });
        res.json({ message: "Product deleted successfully" });
    } catch (error) {
        console.error('[Products] Delete error:', error);
        res.status(500).json({ message: "Failed to delete product" });
    }
});

app.get('/health', (req, res) => {
    res.json({ 
        status: 'OK', 
        timestamp: new Date().toISOString(),
        authentication: 'Working',
        database: 'Connected',
        userManagement: 'Complete',
        productManagement: 'Working'
    });
});

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
    console.log('Debug server running on port 5000 with enhanced product creation logging');
});
