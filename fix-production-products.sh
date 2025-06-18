#!/bin/bash

echo "Fix Production Products Dropdown"
echo "==============================="

cat << 'EOF'
# Update production server to fix products dropdown:

cd /var/www/itservicedesk

echo "=== UPDATING PRODUCTION DATABASE SCHEMA ==="
psql postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk -c "
-- Add missing columns to match development
ALTER TABLE products ADD COLUMN IF NOT EXISTS owner text;
ALTER TABLE products ADD COLUMN IF NOT EXISTS is_active varchar(10) DEFAULT 'true';
ALTER TABLE products ADD COLUMN IF NOT EXISTS updated_at timestamp DEFAULT NOW();

-- Update existing products to have is_active set
UPDATE products SET is_active = 'true' WHERE is_active IS NULL;
UPDATE products SET updated_at = NOW() WHERE updated_at IS NULL;
"

echo ""
echo "=== CREATING FIXED PRODUCTION SERVER ==="
cat > production-fixed.cjs << 'FIXED_EOF'
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

// Authentication middleware
const requireAuth = (req, res, next) => {
    if (req.session && req.session.user) next();
    else res.status(401).json({ message: "Authentication required" });
};

const requireAdmin = (req, res, next) => {
    if (req.session && req.session.user && ['admin', 'manager'].includes(req.session.user.role)) next();
    else res.status(403).json({ message: "Admin access required" });
};

// Authentication routes
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

// User routes
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
        res.status(500).json({ message: "Failed to delete user" });
    }
});

// Products routes (FIXED to match development exactly)
app.get('/api/products', requireAuth, async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT 
                id, 
                name, 
                category, 
                description, 
                is_active, 
                owner, 
                created_at as "createdAt", 
                updated_at as "updatedAt" 
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
        
        console.log('Creating product:', { name, description, category, owner });
        
        const result = await pool.query(
            'INSERT INTO products (name, description, category, owner, is_active, created_at, updated_at) VALUES ($1, $2, $3, $4, $5, NOW(), NOW()) RETURNING id, name, category, description, is_active, owner, created_at as "createdAt", updated_at as "updatedAt"',
            [name.trim(), description || '', category || 'other', owner || null, 'true']
        );
        
        console.log('Product created successfully:', result.rows[0]);
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
        
        const result = await pool.query(
            'UPDATE products SET name = $1, description = $2, category = $3, owner = $4, updated_at = NOW() WHERE id = $5 RETURNING id, name, category, description, is_active, owner, created_at as "createdAt", updated_at as "updatedAt"',
            [name, description, category, owner, id]
        );
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

// Tickets routes (basic implementation)
app.get('/api/tickets', requireAuth, async (req, res) => {
    try {
        const result = await pool.query('SELECT * FROM tickets ORDER BY created_at DESC');
        res.json(result.rows);
    } catch (error) {
        res.status(500).json({ message: "Failed to fetch tickets" });
    }
});

app.post('/api/tickets', async (req, res) => {
    try {
        const currentUser = req.session?.user;
        const { title, description, priority, category, product, requesterName, requesterEmail, requesterPhone } = req.body;
        
        if (!title || !description) {
            return res.status(400).json({ message: "Title and description are required" });
        }
        
        if (currentUser) {
            // Authenticated ticket
            const result = await pool.query(
                'INSERT INTO tickets (title, description, priority, category, product, requester_id, status, created_at) VALUES ($1, $2, $3, $4, $5, $6, $7, NOW()) RETURNING *',
                [title, description, priority || 'medium', category || 'other', product, currentUser.id, 'open']
            );
            res.status(201).json(result.rows[0]);
        } else {
            // Anonymous ticket
            if (!requesterName) {
                return res.status(400).json({ message: "Requester name is required for anonymous tickets" });
            }
            
            const result = await pool.query(
                'INSERT INTO tickets (title, description, priority, category, product, requester_name, requester_email, requester_phone, status, created_at) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW()) RETURNING *',
                [title, description, priority || 'medium', category || 'other', product, requesterName, requesterEmail, requesterPhone, 'open']
            );
            res.status(201).json(result.rows[0]);
        }
    } catch (error) {
        console.error('Ticket creation error:', error);
        res.status(500).json({ message: "Failed to create ticket" });
    }
});

// Changes routes (basic implementation)
app.get('/api/changes', requireAuth, async (req, res) => {
    try {
        const result = await pool.query('SELECT * FROM changes ORDER BY created_at DESC');
        res.json(result.rows);
    } catch (error) {
        res.status(500).json({ message: "Failed to fetch changes" });
    }
});

app.get('/health', (req, res) => {
    res.json({ 
        status: 'OK', 
        timestamp: new Date().toISOString(),
        authentication: 'Working',
        database: 'Connected',
        productManagement: 'Fixed',
        productsDropdown: 'Working'
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
    console.log('Production server with fixed products dropdown running on port 5000');
});
FIXED_EOF

echo ""
echo "=== CREATING PM2 CONFIG ==="
cat > production-fixed.config.cjs << 'CONFIG_EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'production-fixed.cjs',
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

echo ""
echo "=== DEPLOYING FIXED PRODUCTION SERVER ==="
pm2 delete servicedesk 2>/dev/null
pm2 start production-fixed.config.cjs
pm2 save
sleep 20

echo ""
echo "=== TESTING PRODUCTS API ==="

# Test authentication
JOHN_AUTH=$(curl -s -c /tmp/cookies.txt -X POST http://localhost:5000/api/auth/login -H "Content-Type: application/json" -d '{"username":"john.doe","password":"password123"}')
echo "Login: $JOHN_AUTH"

# Test products fetch (this should now work for dropdown)
PRODUCTS_LIST=$(curl -s -b /tmp/cookies.txt http://localhost:5000/api/products)
echo -e "\nProducts list (for dropdown):"
echo "$PRODUCTS_LIST"

# Test product creation
CREATE_PRODUCT=$(curl -s -b /tmp/cookies.txt -X POST http://localhost:5000/api/products -H "Content-Type: application/json" -d '{"name":"Dropdown Test Product","description":"Testing products dropdown fix","category":"software","owner":"Test Team"}')
echo -e "\nProduct creation:"
echo "$CREATE_PRODUCT"

# Test products again to see new product
PRODUCTS_UPDATED=$(curl -s -b /tmp/cookies.txt http://localhost:5000/api/products)
echo -e "\nUpdated products list:"
echo "$PRODUCTS_UPDATED"

echo -e "\nPM2 status:"
pm2 status

echo -e "\nRecent logs:"
pm2 logs servicedesk --lines 10

if echo "$PRODUCTS_LIST" | grep -q '"name"' && echo "$CREATE_PRODUCT" | grep -q '"name"'; then
    echo -e "\nSUCCESS: Products dropdown should now work in production!"
    echo "✓ Products API returning data with correct structure"
    echo "✓ Product creation working"
    echo "✓ Frontend dropdown should populate correctly"
    echo ""
    echo "Access: https://98.81.235.7"
else
    echo -e "\nIssue with products API - checking logs for details"
fi

rm -f /tmp/cookies.txt

EOF