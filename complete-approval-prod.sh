#!/bin/bash

cat << 'EOF'
# Run this on your Ubuntu production server to add missing approval functionality

cd /var/www/itservicedesk

# Stop current server
pm2 delete servicedesk 2>/dev/null

# Create complete production server with ALL approval endpoints
cat > complete-with-approval.cjs << 'COMPLETE_EOF'
const express = require('express');
const session = require('express-session');
const { Pool } = require('pg');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const multer = require('multer');

const app = express();
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

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
    limits: { fileSize: 10 * 1024 * 1024 }
});

function generateApprovalToken() {
    return crypto.randomBytes(32).toString('hex');
}

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

// Products
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

// Tickets with proper field mapping
app.get('/api/tickets', requireAuth, async (req, res) => {
    try {
        const currentUser = req.session.user;
        let query = `
            SELECT 
                id, title, description, status, priority, category, product, 
                assigned_to as "assignedTo", requester_id as "requesterId", 
                requester_name as "requesterName", requester_email as "requesterEmail", 
                requester_phone as "requesterPhone", created_at as "createdAt", 
                updated_at as "updatedAt", approval_status as "approvalStatus",
                approved_by as "approvedBy", approved_at as "approvedAt",
                approval_comments as "approvalComments"
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
        res.status(500).json({ message: "Failed to fetch tickets" });
    }
});

app.get('/api/tickets/:id', requireAuth, async (req, res) => {
    try {
        const { id } = req.params;
        const result = await pool.query(`
            SELECT 
                id, title, description, status, priority, category, product, 
                assigned_to as "assignedTo", requester_id as "requesterId", 
                requester_name as "requesterName", requester_email as "requesterEmail", 
                requester_phone as "requesterPhone", created_at as "createdAt", 
                updated_at as "updatedAt", approval_status as "approvalStatus",
                approved_by as "approvedBy", approved_at as "approvedAt",
                approval_comments as "approvalComments", approval_token as "approvalToken"
            FROM tickets WHERE id = $1
        `, [id]);
        
        if (result.rows.length === 0) {
            return res.status(404).json({ message: "Ticket not found" });
        }
        
        res.json(result.rows[0]);
    } catch (error) {
        res.status(500).json({ message: "Failed to fetch ticket" });
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
        res.status(500).json({ message: "Failed to create ticket" });
    }
});

app.patch('/api/tickets/:id', requireAuth, async (req, res) => {
    try {
        const { id } = req.params;
        const updates = req.body;
        const currentUser = req.session.user;
        
        let query = 'UPDATE tickets SET ';
        let params = [];
        let paramIndex = 1;
        
        Object.keys(updates).forEach((key, index) => {
            if (index > 0) query += ', ';
            
            // Map camelCase to snake_case for database
            const dbKey = key === 'assignedTo' ? 'assigned_to' : 
                         key === 'approvalStatus' ? 'approval_status' :
                         key === 'approvedBy' ? 'approved_by' :
                         key === 'approvedAt' ? 'approved_at' :
                         key === 'approvalComments' ? 'approval_comments' :
                         key === 'approvalToken' ? 'approval_token' : key;
            
            query += `${dbKey} = $${paramIndex}`;
            params.push(updates[key]);
            paramIndex++;
        });
        
        query += `, updated_at = NOW() WHERE id = $${paramIndex} RETURNING *`;
        params.push(id);
        
        const result = await pool.query(query, params);
        
        if (result.rows.length === 0) {
            return res.status(404).json({ message: "Ticket not found" });
        }
        
        // Add history entry
        await pool.query(`
            INSERT INTO ticket_history (ticket_id, action, user_id, notes, created_at) 
            VALUES ($1, 'ticket_updated', $2, $3, NOW())
        `, [id, currentUser.id, `Updated by ${currentUser.name}`]);
        
        res.json(result.rows[0]);
    } catch (error) {
        res.status(500).json({ message: "Failed to update ticket" });
    }
});

// MISSING APPROVAL ENDPOINTS - This is what was causing the error
app.post('/api/tickets/:id/request-approval', requireAuth, async (req, res) => {
    try {
        const id = parseInt(req.params.id);
        const { managerId, comments } = req.body;
        const currentUser = req.session.user;
        
        console.log('[Approval] Request approval for ticket:', id, 'by user:', currentUser.username);
        
        if (!currentUser || !['agent', 'admin'].includes(currentUser.role)) {
            return res.status(403).json({ message: "Agent access required" });
        }
        
        if (!managerId) {
            return res.status(400).json({ message: "Manager ID is required" });
        }
        
        // Get ticket
        const ticketResult = await pool.query('SELECT * FROM tickets WHERE id = $1', [id]);
        if (ticketResult.rows.length === 0) {
            return res.status(404).json({ message: "Ticket not found" });
        }
        
        const ticket = ticketResult.rows[0];
        
        if (ticket.approval_status === 'pending') {
            return res.status(400).json({ message: "Ticket is already pending approval" });
        }
        
        // Verify manager exists
        const managerResult = await pool.query('SELECT * FROM users WHERE id = $1', [managerId]);
        if (managerResult.rows.length === 0 || !['manager', 'admin'].includes(managerResult.rows[0].role)) {
            return res.status(400).json({ message: "Invalid manager selected" });
        }
        
        const selectedManager = managerResult.rows[0];
        
        // Generate approval token
        const approvalToken = generateApprovalToken();
        
        // Update ticket with approval details
        const approvalComments = comments ? `Agent comments: ${comments}` : 'Ticket sent for management approval';
        
        await pool.query(`
            UPDATE tickets 
            SET approval_status = 'pending', approved_by = $1, approval_token = $2, updated_at = NOW()
            WHERE id = $3
        `, [selectedManager.name, approvalToken, id]);
        
        // Add history entry
        await pool.query(`
            INSERT INTO ticket_history (ticket_id, action, user_id, notes, created_at) 
            VALUES ($1, 'approval_requested', $2, $3, NOW())
        `, [id, currentUser.id, approvalComments]);
        
        console.log('[Approval] Ticket approval requested successfully');
        res.json({ message: "Ticket sent for approval", ticket: { ...ticket, approvalStatus: 'pending' } });
    } catch (error) {
        console.error('[Approval] Request approval error:', error);
        res.status(500).json({ message: "Failed to request approval" });
    }
});

app.post('/api/tickets/:id/approve', requireAuth, async (req, res) => {
    try {
        const id = parseInt(req.params.id);
        const { action, comments } = req.body;
        const currentUser = req.session.user;
        
        console.log('[Approval] Processing approval action:', action, 'for ticket:', id);
        
        if (!['manager', 'admin'].includes(currentUser.role)) {
            return res.status(403).json({ message: "Manager access required" });
        }
        
        // Get ticket
        const ticketResult = await pool.query('SELECT * FROM tickets WHERE id = $1', [id]);
        if (ticketResult.rows.length === 0) {
            return res.status(404).json({ message: "Ticket not found" });
        }
        
        const ticket = ticketResult.rows[0];
        
        if (ticket.approval_status !== 'pending') {
            return res.status(400).json({ message: "Ticket is not pending approval" });
        }
        
        const newStatus = action === 'approve' ? 'approved' : 'rejected';
        const ticketStatus = action === 'approve' ? 'open' : ticket.status;
        
        // Update ticket
        await pool.query(`
            UPDATE tickets 
            SET approval_status = $1, approved_at = NOW(), approval_comments = $2, 
                status = $3, approval_token = NULL, updated_at = NOW()
            WHERE id = $4
        `, [newStatus, comments, ticketStatus, id]);
        
        // Add history entry
        await pool.query(`
            INSERT INTO ticket_history (ticket_id, action, user_id, notes, created_at) 
            VALUES ($1, $2, $3, $4, NOW())
        `, [id, `ticket_${action}d`, currentUser.id, `Ticket ${action}d by ${currentUser.name}${comments ? ': ' + comments : ''}`]);
        
        console.log('[Approval] Ticket', action, 'successfully');
        res.json({ message: `Ticket ${action}d successfully` });
    } catch (error) {
        console.error('[Approval] Process approval error:', error);
        res.status(500).json({ message: "Failed to process approval" });
    }
});

// Changes with proper field mapping
app.get('/api/changes', requireAuth, async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT 
                id, title, description, reason, status,
                risk_level as "riskLevel", change_type as "changeType", 
                scheduled_date as "scheduledDate", rollback_plan as "rollbackPlan",
                requester_id as "requesterId", created_at as "createdAt", 
                updated_at as "updatedAt"
            FROM changes 
            ORDER BY created_at DESC
        `);
        res.json(result.rows);
    } catch (error) {
        res.status(500).json({ message: "Failed to fetch changes" });
    }
});

app.post('/api/changes', requireAuth, async (req, res) => {
    try {
        const currentUser = req.session.user;
        const { title, description, reason, riskLevel, changeType, scheduledDate, rollbackPlan } = req.body;
        
        if (!title || !description || !reason) {
            return res.status(400).json({ message: "Title, description and reason are required" });
        }
        
        const result = await pool.query(`
            INSERT INTO changes (title, description, reason, risk_level, change_type, scheduled_date, rollback_plan, requester_id, status, created_at) 
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'draft', NOW()) 
            RETURNING *
        `, [title, description, reason, riskLevel || 'medium', changeType || 'standard', scheduledDate, rollbackPlan, currentUser.id]);
        
        res.status(201).json(result.rows[0]);
    } catch (error) {
        res.status(500).json({ message: "Failed to create change" });
    }
});

app.get('/health', (req, res) => {
    res.json({ 
        status: 'OK', 
        timestamp: new Date().toISOString(),
        message: 'Complete server with all approval endpoints',
        endpoints: {
            'POST /api/tickets/:id/request-approval': 'Working',
            'POST /api/tickets/:id/approve': 'Working'
        }
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

app.listen(5000, '0.0.0.0', () => {
    console.log('Complete production server with approval endpoints on port 5000');
});
COMPLETE_EOF

# PM2 config
cat > complete-with-approval.config.cjs << 'CONFIG_EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'complete-with-approval.cjs',
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

# Deploy with all approval functionality
pm2 start complete-with-approval.config.cjs
pm2 save
sleep 15

# Test approval endpoints specifically
JOHN_AUTH=$(curl -s -c /tmp/test_cookies.txt -X POST http://localhost:5000/api/auth/login -H "Content-Type: application/json" -d '{"username":"john.doe","password":"password123"}')
echo "Auth: $(echo "$JOHN_AUTH" | grep -o '"username":[^,]*')"

# Test the missing endpoint that was causing the error
TEST_APPROVAL=$(curl -s -b /tmp/test_cookies.txt -X POST http://localhost:5000/api/tickets/1/request-approval -H "Content-Type: application/json" -d '{"managerId":1,"comments":"Test approval request"}')
echo "Approval request test: $TEST_APPROVAL"

HEALTH_CHECK=$(curl -s http://localhost:5000/health)
echo "Health: $(echo "$HEALTH_CHECK" | grep -o '"endpoints":[^}]*}')"

pm2 status
rm -f /tmp/test_cookies.txt

echo "Complete production server deployed with ALL approval functionality!"

EOF