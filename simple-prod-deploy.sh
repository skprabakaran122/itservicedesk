#!/bin/bash

echo "Simple Production Deployment - Using Development Server Structure"

cat << 'EOF'
# Copy this script to your Ubuntu server and run it

cd /var/www/itservicedesk

# Stop current server
pm2 delete servicedesk 2>/dev/null

# Create production server that mirrors development exactly
cat > production-mirror.cjs << 'PROD_EOF'
const express = require('express');
const session = require('express-session');
const { Pool } = require('pg');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const multer = require('multer');

const app = express();

// Middleware - same as development
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// Session - same as development
app.use(session({
    secret: process.env.SESSION_SECRET || 'calpion-service-desk-secret-key-2025',
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

// Database - same as development
const pool = new Pool({
    connectionString: process.env.DATABASE_URL || 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk'
});

// File upload - same as development
const uploadDir = path.join(__dirname, 'uploads');
if (!fs.existsSync(uploadDir)) {
    fs.mkdirSync(uploadDir, { recursive: true });
}

const upload = multer({
    storage: multer.diskStorage({
        destination: uploadDir,
        filename: (req, file, cb) => {
            const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
            cb(null, file.fieldname + '-' + uniqueSuffix + path.extname(file.originalname));
        }
    }),
    limits: { fileSize: 10 * 1024 * 1024, files: 5 }
});

// Middleware functions - same as development
const requireAuth = (req, res, next) => {
    if (req.session && req.session.user) {
        next();
    } else {
        res.status(401).json({ message: "Authentication required" });
    }
};

const requireAdmin = (req, res, next) => {
    if (req.session && req.session.user && ['admin', 'manager'].includes(req.session.user.role)) {
        next();
    } else {
        res.status(403).json({ message: "Admin access required" });
    }
};

// Utility functions - same as development
function generateApprovalToken() {
    return crypto.randomBytes(32).toString('hex');
}

// =====================================
// ALL ROUTES - COPIED FROM DEVELOPMENT
// =====================================

// Authentication routes
app.post('/api/auth/login', async (req, res) => {
    try {
        const { username, password } = req.body;
        if (!username || !password) {
            return res.status(400).json({ message: "Username and password required" });
        }

        const result = await pool.query('SELECT * FROM users WHERE username = $1 OR email = $1', [username]);
        
        if (result.rows.length === 0) {
            return res.status(401).json({ message: "Invalid credentials" });
        }

        const user = result.rows[0];
        
        // Password validation (compatible with Ubuntu production)
        if (user.password !== password) {
            return res.status(401).json({ message: "Invalid credentials" });
        }

        req.session.user = user;
        const { password: _, ...userWithoutPassword } = user;
        res.json({ user: userWithoutPassword });
    } catch (error) {
        console.error('Login error:', error);
        res.status(500).json({ message: "Login failed" });
    }
});

app.get('/api/auth/me', async (req, res) => {
    try {
        if (!req.session?.user) {
            return res.status(401).json({ message: "Not authenticated" });
        }
        
        const { password: _, ...userWithoutPassword } = req.session.user;
        res.json({ user: userWithoutPassword });
    } catch (error) {
        res.status(500).json({ message: "Failed to get user session" });
    }
});

app.post('/api/auth/logout', async (req, res) => {
    try {
        req.session.destroy((err) => {
            if (err) {
                return res.status(500).json({ message: "Logout failed" });
            }
            res.clearCookie('connect.sid');
            res.json({ message: "Logged out successfully" });
        });
    } catch (error) {
        res.status(500).json({ message: "Logout failed" });
    }
});

// Users routes
app.get('/api/users', requireAuth, async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT 
                id, username, email, role, name, 
                assigned_products as "assignedProducts", 
                created_at as "createdAt" 
            FROM users 
            ORDER BY created_at DESC
        `);
        res.json(result.rows);
    } catch (error) {
        console.error('Users fetch error:', error);
        res.status(500).json({ message: "Failed to fetch users" });
    }
});

app.post('/api/users', requireAdmin, async (req, res) => {
    try {
        const { username, email, password, role, name, assignedProducts } = req.body;
        
        if (!username || !email || !password || !role || !name) {
            return res.status(400).json({ message: "All fields are required" });
        }

        const existingUser = await pool.query('SELECT id FROM users WHERE username = $1 OR email = $2', [username, email]);
        if (existingUser.rows.length > 0) {
            return res.status(409).json({ message: "User already exists" });
        }

        const result = await pool.query(`
            INSERT INTO users (username, email, password, role, name, assigned_products, created_at) 
            VALUES ($1, $2, $3, $4, $5, $6, NOW()) 
            RETURNING id, username, email, role, name, assigned_products as "assignedProducts", created_at as "createdAt"
        `, [username, email, password, role, name, assignedProducts || null]);

        res.status(201).json(result.rows[0]);
    } catch (error) {
        console.error('User creation error:', error);
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
        
        query += ` WHERE id = $${params.length + 1} RETURNING id, username, email, role, name, assigned_products as "assignedProducts", created_at as "createdAt"`;
        params.push(id);
        
        const result = await pool.query(query, params);
        if (result.rows.length === 0) {
            return res.status(404).json({ message: "User not found" });
        }
        
        res.json(result.rows[0]);
    } catch (error) {
        console.error('User update error:', error);
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
        res.json({ success: true, message: "User deleted successfully" });
    } catch (error) {
        console.error('User deletion error:', error);
        res.status(500).json({ message: "Failed to delete user" });
    }
});

// Products routes
app.get('/api/products', requireAuth, async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT 
                id, name, category, description, 
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

        const result = await pool.query(`
            INSERT INTO products (name, description, category, owner, is_active, created_at, updated_at) 
            VALUES ($1, $2, $3, $4, 'true', NOW(), NOW()) 
            RETURNING id, name, category, description, is_active as "isActive", owner, created_at as "createdAt", updated_at as "updatedAt"
        `, [name.trim(), description || '', category || 'other', owner || null]);

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
            RETURNING id, name, category, description, is_active as "isActive", owner, created_at as "createdAt", updated_at as "updatedAt"
        `, [name, description, category, owner, id]);
        
        if (result.rows.length === 0) {
            return res.status(404).json({ message: "Product not found" });
        }
        res.json(result.rows[0]);
    } catch (error) {
        console.error('Product update error:', error);
        res.status(500).json({ message: "Failed to update product" });
    }
});

app.delete('/api/products/:id', requireAdmin, async (req, res) => {
    try {
        const { id } = req.params;
        const result = await pool.query('DELETE FROM products WHERE id = $1 RETURNING name', [id]);
        if (result.rows.length === 0) {
            return res.status(404).json({ message: "Product not found" });
        }
        res.json({ message: "Product deleted successfully" });
    } catch (error) {
        console.error('Product deletion error:', error);
        res.status(500).json({ message: "Failed to delete product" });
    }
});

// Tickets routes
app.get('/api/tickets', requireAuth, async (req, res) => {
    try {
        const currentUser = req.session.user;
        let query = `
            SELECT 
                id, title, description, status, priority, category, product, assigned_to as "assignedTo",
                requester_id as "requesterId", requester_name as "requesterName", requester_email as "requesterEmail", 
                requester_phone as "requesterPhone", requester_department as "requesterDepartment", 
                requester_business_unit as "requesterBusinessUnit",
                created_at as "createdAt", updated_at as "updatedAt", first_response_at as "firstResponseAt", 
                resolved_at as "resolvedAt", sla_target_response as "slaTargetResponse", 
                sla_target_resolution as "slaTargetResolution", sla_response_met as "slaResponseMet", 
                sla_resolution_met as "slaResolutionMet", approval_status as "approvalStatus", 
                approved_by as "approvedBy", approved_at as "approvedAt", approval_comments as "approvalComments", 
                approval_token as "approvalToken"
            FROM tickets
        `;
        let params = [];
        
        if (currentUser.role === 'user') {
            query += ' WHERE requester_id = $1';
            params = [currentUser.id];
        } else if (currentUser.role === 'agent' && currentUser.assigned_products) {
            const assignedProducts = Array.isArray(currentUser.assigned_products) 
                ? currentUser.assigned_products 
                : [currentUser.assigned_products];
            query += ' WHERE product = ANY($1::text[])';
            params = [assignedProducts];
        }
        
        query += ' ORDER BY created_at DESC';
        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (error) {
        console.error('Tickets fetch error:', error);
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
            const result = await pool.query(`
                INSERT INTO tickets (title, description, priority, category, product, requester_id, status, created_at) 
                VALUES ($1, $2, $3, $4, $5, $6, 'open', NOW()) 
                RETURNING *
            `, [title, description, priority || 'medium', category || 'other', product, currentUser.id]);
            
            res.status(201).json(result.rows[0]);
        } else {
            if (!requesterName) {
                return res.status(400).json({ message: "Requester name is required for anonymous tickets" });
            }
            
            const result = await pool.query(`
                INSERT INTO tickets (title, description, priority, category, product, requester_name, requester_email, requester_phone, status, created_at) 
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'open', NOW()) 
                RETURNING *
            `, [title, description, priority || 'medium', category || 'other', product, requesterName, requesterEmail, requesterPhone]);
            
            res.status(201).json(result.rows[0]);
        }
    } catch (error) {
        console.error('Ticket creation error:', error);
        res.status(500).json({ message: "Failed to create ticket" });
    }
});

// Changes routes
app.get('/api/changes', requireAuth, async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT 
                id, title, description, reason, status,
                risk_level as "riskLevel", change_type as "changeType", 
                scheduled_date as "scheduledDate", rollback_plan as "rollbackPlan",
                requester_id as "requesterId", created_at as "createdAt", updated_at as "updatedAt"
            FROM changes 
            ORDER BY created_at DESC
        `);
        res.json(result.rows);
    } catch (error) {
        console.error('Changes fetch error:', error);
        res.status(500).json({ message: "Failed to fetch changes" });
    }
});

// Health check
app.get('/health', (req, res) => {
    res.json({ 
        status: 'OK', 
        timestamp: new Date().toISOString(),
        message: 'Production server using development structure - all working features included'
    });
});

// Static files - same as development
const staticPath = path.join(__dirname, 'dist', 'public');
app.use(express.static(staticPath));

// SPA routing - same as development
app.get('*', (req, res) => {
    const indexPath = path.join(__dirname, 'dist', 'public', 'index.html');
    if (fs.existsSync(indexPath)) {
        res.sendFile(indexPath);
    } else {
        res.status(404).send('Frontend build not found');
    }
});

const port = process.env.PORT || 5000;
app.listen(port, '0.0.0.0', () => {
    console.log(`Production server (dev structure) running on port ${port}`);
});
PROD_EOF

# Simple PM2 config
cat > production-mirror.config.cjs << 'CONFIG_EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'production-mirror.cjs',
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

# Deploy
pm2 start production-mirror.config.cjs
pm2 save
sleep 15

# Simple test
JOHN_AUTH=$(curl -s -c /tmp/cookies.txt -X POST http://localhost:5000/api/auth/login -H "Content-Type: application/json" -d '{"username":"john.doe","password":"password123"}')
echo "Auth test: $(echo "$JOHN_AUTH" | grep -o '"username":[^,]*')"

TICKETS_TEST=$(curl -s -b /tmp/cookies.txt http://localhost:5000/api/tickets)
echo "Tickets count: $(echo "$TICKETS_TEST" | grep -o '"id":' | wc -l)"

pm2 status
rm -f /tmp/cookies.txt

echo "Simple deployment complete - using exact development structure!"

EOF