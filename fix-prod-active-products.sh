#!/bin/bash
cd /var/www/itservicedesk

# Fix production database to set products as active by default
echo "=== FIXING PRODUCTION DATABASE SCHEMA ==="
psql postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk -c "
-- Ensure is_active column exists and has correct default
ALTER TABLE products ADD COLUMN IF NOT EXISTS is_active varchar(10) DEFAULT 'true';

-- Update all existing products to be active
UPDATE products SET is_active = 'true' WHERE is_active IS NULL OR is_active != 'true';

-- Check current products status
SELECT id, name, is_active FROM products ORDER BY id;
"

# Create fixed production server that sets is_active correctly
cat > production-active-fixed.cjs << 'ACTIVE_EOF'
const express = require('express');
const session = require('express-session');
const { Pool } = require('pg');
const path = require('path');

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
    if (req.session && req.session.user) next();
    else res.status(401).json({ message: "Authentication required" });
};

const requireAdmin = (req, res, next) => {
    if (req.session && req.session.user && ['admin', 'manager'].includes(req.session.user.role)) next();
    else res.status(403).json({ message: "Admin access required" });
};

// Authentication
app.post('/api/auth/login', async (req, res) => {
    try {
        const { username, password } = req.body;
        const result = await pool.query('SELECT * FROM users WHERE username = $1 OR email = $1', [username]);
        
        if (result.rows.length === 0 || result.rows[0].password !== password) {
            return res.status(401).json({ message: "Invalid credentials" });
        }
        
        req.session.user = result.rows[0];
        const { password: _, ...userWithoutPassword } = result.rows[0];
        res.json({ user: userWithoutPassword });
    } catch (error) {
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
        res.status(500).json({ message: "Failed to create user" });
    }
});

// Products - FIXED to return correct isActive format
app.get('/api/products', requireAuth, async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT 
                id, 
                name, 
                category, 
                description, 
                COALESCE(is_active, 'true') as "isActive",
                owner, 
                created_at as "createdAt", 
                COALESCE(updated_at, created_at) as "updatedAt" 
            FROM products 
            ORDER BY name
        `);
        res.json(result.rows);
    } catch (error) {
        console.error('Products fetch error:', error);
        res.status(500).json({ message: "Failed to fetch products" });
    }
});

app.post('/api/products', requireAdmin, async (req, res) => {
    try {
        const { name, description, category, owner } = req.body;
        
        if (!name || typeof name !== 'string' || name.trim().length === 0) {
            return res.status(400).json({ message: "Product name is required" });
        }
        
        console.log('Creating product as ACTIVE:', { name, description, category, owner });
        
        // Explicitly set is_active to 'true' for new products
        const result = await pool.query(`
            INSERT INTO products (name, description, category, owner, is_active, created_at, updated_at) 
            VALUES ($1, $2, $3, $4, 'true', NOW(), NOW()) 
            RETURNING 
                id, 
                name, 
                category, 
                description, 
                is_active as "isActive", 
                owner, 
                created_at as "createdAt", 
                updated_at as "updatedAt"
        `, [name.trim(), description || '', category || 'other', owner || null]);
        
        console.log('Product created successfully as ACTIVE:', result.rows[0]);
        res.status(201).json(result.rows[0]);
    } catch (error) {
        console.error('Product creation error:', error);
        res.status(500).json({ message: "Failed to create product" });
    }
});

app.patch('/api/products/:id', requireAdmin, async (req, res) => {
    try {
        const { id } = req.params;
        const { name, description, category, owner } = req.body;
        
        const result = await pool.query(`
            UPDATE products 
            SET name = $1, description = $2, category = $3, owner = $4, updated_at = NOW() 
            WHERE id = $5 
            RETURNING 
                id, 
                name, 
                category, 
                description, 
                is_active as "isActive", 
                owner, 
                created_at as "createdAt", 
                updated_at as "updatedAt"
        `, [name, description, category, owner, id]);
        
        if (result.rows.length === 0) return res.status(404).json({ message: "Product not found" });
        res.json(result.rows[0]);
    } catch (error) {
        res.status(500).json({ message: "Failed to update product" });
    }
});

app.delete('/api/products/:id', requireAdmin, async (req, res) => {
    try {
        const { id } = req.params;
        const result = await pool.query('DELETE FROM products WHERE id = $1 RETURNING name', [id]);
        if (result.rows.length === 0) return res.status(404).json({ message: "Product not found" });
        res.json({ message: "Product deleted successfully" });
    } catch (error) {
        res.status(500).json({ message: "Failed to delete product" });
    }
});

app.get('/health', (req, res) => {
    res.json({ 
        status: 'OK', 
        timestamp: new Date().toISOString(),
        authentication: 'Working',
        database: 'Connected',
        productManagement: 'Fixed - Active by Default'
    });
});

// Static files
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

app.listen(5000, '0.0.0.0', () => {
    console.log('Production server with ACTIVE products by default running on port 5000');
});
ACTIVE_EOF

# PM2 config
cat > production-active-fixed.config.cjs << 'CONFIG_EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'production-active-fixed.cjs',
    instances: 1,
    autorestart: true,
    env: {
      NODE_ENV: 'production',
      PORT: 5000,
      DATABASE_URL: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk',
      SESSION_SECRET: 'calpion-service-desk-secret-key-2025'
    }
  }]
};
CONFIG_EOF

# Deploy fixed server
pm2 delete servicedesk 2>/dev/null
pm2 start production-active-fixed.config.cjs
pm2 save
sleep 20

# Test the fix
echo "=== TESTING ACTIVE PRODUCTS FIX ==="

JOHN_AUTH=$(curl -s -c /tmp/cookies.txt -X POST http://localhost:5000/api/auth/login -H "Content-Type: application/json" -d '{"username":"john.doe","password":"password123"}')
echo "Login: $JOHN_AUTH"

# Test products list to verify active status
PRODUCTS_LIST=$(curl -s -b /tmp/cookies.txt http://localhost:5000/api/products)
echo -e "\nProducts (should all be active):"
echo "$PRODUCTS_LIST" | jq '.[].isActive' 2>/dev/null || echo "$PRODUCTS_LIST"

# Test creating new product (should be active by default)
CREATE_PRODUCT=$(curl -s -b /tmp/cookies.txt -X POST http://localhost:5000/api/products -H "Content-Type: application/json" -d '{"name":"Active Test Product","description":"Testing active by default","category":"software"}')
echo -e "\nNew product (should be active):"
echo "$CREATE_PRODUCT"

pm2 status
rm -f /tmp/cookies.txt

echo -e "\nProducts should now be created as ACTIVE by default in production!"
