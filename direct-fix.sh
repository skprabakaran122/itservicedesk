#!/bin/bash
cd /var/www/itservicedesk

# First, let's check the actual database structure
echo "=== CHECKING PRODUCTION DATABASE STRUCTURE ==="
psql postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk -c "
SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';
"

echo -e "\n=== CHECKING PRODUCTS TABLE STRUCTURE ==="
psql postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk -c "
\d products
"

echo -e "\n=== CHECKING EXISTING PRODUCTS ==="
psql postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk -c "
SELECT * FROM products;
"

echo -e "\n=== TESTING DIRECT INSERT ==="
psql postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk -c "
INSERT INTO products (name, description, category, owner, created_at) 
VALUES ('Direct SQL Test', 'Testing direct SQL insert', 'software', null, NOW()) 
RETURNING *;
"

echo -e "\n=== CREATING ULTRA-SIMPLE SERVER ==="
cat > ultra-simple.cjs << 'SIMPLE_EOF'
const express = require('express');
const session = require('express-session');
const { Pool } = require('pg');
const path = require('path');

const app = express();
app.use(express.json());

app.use(session({
    secret: 'calpion-service-desk-secret-key-2025',
    resave: false,
    saveUninitialized: false,
    name: 'connect.sid',
    cookie: { secure: false, httpOnly: true, maxAge: 24 * 60 * 60 * 1000 }
}));

const pool = new Pool({
    connectionString: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk'
});

// Test database connection
pool.query('SELECT NOW()', (err, res) => {
    if (err) {
        console.error('Database connection failed:', err);
    } else {
        console.log('Database connected successfully at:', res.rows[0].now);
    }
});

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
        console.log('Login successful for:', username, 'Role:', result.rows[0].role);
        res.json({ user: userWithoutPassword });
    } catch (error) {
        console.error('Login error:', error);
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

// Ultra-simple product creation (no middleware complications)
app.post('/api/products', async (req, res) => {
    try {
        console.log('=== PRODUCT CREATION REQUEST ===');
        console.log('Session user:', req.session?.user?.username);
        console.log('User role:', req.session?.user?.role);
        console.log('Request body:', req.body);
        
        // Check authentication
        if (!req.session || !req.session.user) {
            console.log('Not authenticated');
            return res.status(401).json({ message: "Authentication required" });
        }
        
        // Check admin role
        if (!['admin', 'manager'].includes(req.session.user.role)) {
            console.log('Not admin - role is:', req.session.user.role);
            return res.status(403).json({ message: "Admin access required" });
        }
        
        const { name, description, category, owner } = req.body;
        
        if (!name) {
            console.log('No name provided');
            return res.status(400).json({ message: "Product name is required" });
        }
        
        console.log('Attempting database insert...');
        
        // Direct database insert - simplest possible
        const result = await pool.query(
            'INSERT INTO products (name, description, category, owner, created_at) VALUES ($1, $2, $3, $4, NOW()) RETURNING *',
            [name, description || '', category || 'other', owner || null]
        );
        
        console.log('Insert successful:', result.rows[0]);
        res.status(201).json(result.rows[0]);
        
    } catch (error) {
        console.error('=== PRODUCT CREATION ERROR ===');
        console.error('Error code:', error.code);
        console.error('Error message:', error.message);
        console.error('Error detail:', error.detail);
        console.error('Full error:', error);
        res.status(500).json({ 
            message: "Failed to create product",
            error: error.message,
            code: error.code
        });
    }
});

app.get('/api/products', async (req, res) => {
    try {
        if (!req.session || !req.session.user) {
            return res.status(401).json({ message: "Authentication required" });
        }
        
        const result = await pool.query('SELECT * FROM products ORDER BY created_at DESC');
        console.log('Products fetched:', result.rows.length);
        res.json(result.rows);
    } catch (error) {
        console.error('Products fetch error:', error);
        res.status(500).json({ message: "Failed to fetch products" });
    }
});

app.get('/health', (req, res) => {
    res.json({ 
        status: 'OK',
        timestamp: new Date().toISOString(),
        database: 'Connected'
    });
});

// Serve static files
const staticPath = path.join(__dirname, 'dist', 'public');
app.use(express.static(staticPath));

app.get('*', (req, res) => {
    const indexPath = path.join(__dirname, 'dist', 'public', 'index.html');
    res.sendFile(indexPath);
});

const port = 5000;
app.listen(port, '0.0.0.0', () => {
    console.log('Ultra-simple server running on port 5000');
    console.log('Debugging product creation issues...');
});
SIMPLE_EOF

# PM2 config
cat > ultra-simple.config.cjs << 'CONFIG_EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'ultra-simple.cjs',
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

# Deploy ultra-simple server
pm2 delete servicedesk 2>/dev/null
pm2 start ultra-simple.config.cjs
pm2 save
sleep 15

echo -e "\n=== TESTING ULTRA-SIMPLE SERVER ==="
curl -s http://localhost:5000/health

echo -e "\nLogin test:"
JOHN_AUTH=$(curl -s -c /tmp/cookies.txt -X POST http://localhost:5000/api/auth/login -H "Content-Type: application/json" -d '{"username":"john.doe","password":"password123"}')
echo "$JOHN_AUTH"

echo -e "\nProduct creation test:"
CREATE_RESULT=$(curl -s -b /tmp/cookies.txt -X POST http://localhost:5000/api/products -H "Content-Type: application/json" -d '{"name":"Ultra Simple Test","description":"Testing ultra-simple server","category":"software"}')
echo "$CREATE_RESULT"

echo -e "\nProducts list:"
PRODUCTS_LIST=$(curl -s -b /tmp/cookies.txt http://localhost:5000/api/products)
echo "$PRODUCTS_LIST"

echo -e "\nPM2 logs (last 20 lines):"
pm2 logs servicedesk --lines 20

rm -f /tmp/cookies.txt
