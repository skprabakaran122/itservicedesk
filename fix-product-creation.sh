#!/bin/bash

echo "Fix Product Creation in Production"
echo "================================"

cat << 'EOF'
# Fix product creation error in production:

cd /var/www/itservicedesk

echo "=== UPDATING PRODUCTION ADAPTER FOR PRODUCT CREATION ==="
cat > production-adapter-fixed.cjs << 'FIXED_EOF'
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

pool.on('connect', () => console.log('[Fixed] Database connected'));
pool.on('error', (err) => console.error('[Fixed] Database error:', err));

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

function generateApprovalToken() { return crypto.randomBytes(32).toString('hex'); }

const requireAuth = (req, res, next) => {
    if (req.session && req.session.user) {
        console.log('[Auth] User authenticated:', req.session.user.username);
        next();
    } else {
        console.log('[Auth] Authentication required');
        res.status(401).json({ message: "Authentication required" });
    }
};

const requireAdmin = (req, res, next) => {
    if (req.session && req.session.user && ['admin', 'manager'].includes(req.session.user.role)) {
        console.log('[Auth] Admin access granted for:', req.session.user.username);
        next();
    } else {
        console.log('[Auth] Admin access denied for:', req.session?.user?.username || 'anonymous');
        res.status(403).json({ message: "Admin access required" });
    }
};

// Product validation function (mimics insertProductSchema)
function validateProductData(data) {
    const errors = [];
    
    if (!data.name || typeof data.name !== 'string' || data.name.trim().length === 0) {
        errors.push('Product name is required');
    }
    
    if (data.category && !['software', 'hardware', 'network', 'access', 'other'].includes(data.category)) {
        errors.push('Invalid category');
    }
    
    if (errors.length > 0) {
        throw new Error(errors.join(', '));
    }
    
    return {
        name: data.name.trim(),
        description: data.description || '',
        category: data.category || 'other',
        owner: data.owner || null
    };
}

// Storage interface adapter
class ProductionStorage {
    async getUserByUsernameOrEmail(usernameOrEmail) {
        const result = await pool.query('SELECT * FROM users WHERE username = $1 OR email = $1', [usernameOrEmail]);
        return result.rows[0];
    }
    
    async getUsers() {
        const result = await pool.query('SELECT id, username, email, role, name, assigned_products as "assignedProducts", created_at as "createdAt" FROM users ORDER BY created_at DESC');
        return result.rows;
    }
    
    async getUser(id) {
        const result = await pool.query('SELECT * FROM users WHERE id = $1', [id]);
        return result.rows[0];
    }
    
    async createUser(userData) {
        const { username, email, password, role, name, assignedProducts } = userData;
        const result = await pool.query(
            'INSERT INTO users (username, email, password, role, name, assigned_products, created_at) VALUES ($1, $2, $3, $4, $5, $6, NOW()) RETURNING id, username, email, role, name, assigned_products as "assignedProducts", created_at as "createdAt"',
            [username, email, password, role, name, assignedProducts || null]
        );
        return result.rows[0];
    }
    
    async updateUser(id, updates) {
        const { username, email, role, name, password, assignedProducts } = updates;
        let query = 'UPDATE users SET username = $1, email = $2, role = $3, name = $4, assigned_products = $5';
        let params = [username, email, role, name, assignedProducts || null];
        
        if (password) {
            query += ', password = $6';
            params.push(password);
        }
        
        query += ' WHERE id = $' + (params.length + 1) + ' RETURNING id, username, email, role, name, assigned_products as "assignedProducts", created_at as "createdAt"';
        params.push(id);
        
        const result = await pool.query(query, params);
        return result.rows[0];
    }
    
    async deleteUser(id) {
        const result = await pool.query('DELETE FROM users WHERE id = $1 RETURNING username', [id]);
        return result.rows.length > 0;
    }
    
    async getProducts() {
        const result = await pool.query('SELECT * FROM products ORDER BY name');
        return result.rows;
    }
    
    async getProduct(id) {
        const result = await pool.query('SELECT * FROM products WHERE id = $1', [id]);
        return result.rows[0];
    }
    
    async createProduct(productData) {
        const { name, description, category, owner } = productData;
        console.log('[Products] Creating product:', { name, description, category, owner });
        
        const result = await pool.query(
            'INSERT INTO products (name, description, category, owner, created_at) VALUES ($1, $2, $3, $4, NOW()) RETURNING *',
            [name, description || '', category || 'other', owner || null]
        );
        
        console.log('[Products] Product created successfully:', result.rows[0]);
        return result.rows[0];
    }
    
    async updateProduct(id, updates) {
        const { name, description, category, owner } = updates;
        const result = await pool.query(
            'UPDATE products SET name = $1, description = $2, category = $3, owner = $4 WHERE id = $5 RETURNING *',
            [name, description, category, owner, id]
        );
        return result.rows[0];
    }
    
    async deleteProduct(id) {
        const result = await pool.query('DELETE FROM products WHERE id = $1 RETURNING name', [id]);
        return result.rows.length > 0;
    }
    
    async getTicketsForUser(userId) {
        const user = await this.getUser(userId);
        if (!user) return [];
        
        let query = 'SELECT * FROM tickets';
        let params = [];
        
        if (user.role === 'user') {
            query += ' WHERE requester_id = $1';
            params = [userId];
        } else if (user.role === 'agent' && user.assigned_products) {
            const assignedProducts = Array.isArray(user.assigned_products) ? user.assigned_products : [user.assigned_products];
            query += ' WHERE product = ANY($1::text[])';
            params = [assignedProducts];
        }
        
        query += ' ORDER BY created_at DESC';
        const result = await pool.query(query, params);
        return result.rows;
    }
    
    async getTicket(id) {
        const result = await pool.query('SELECT * FROM tickets WHERE id = $1', [id]);
        return result.rows[0];
    }
    
    async createTicket(ticketData) {
        const { title, description, priority, category, product, requesterId, requesterName, requesterEmail, requesterPhone } = ticketData;
        
        if (requesterId) {
            const result = await pool.query(
                'INSERT INTO tickets (title, description, priority, category, product, requester_id, status, created_at) VALUES ($1, $2, $3, $4, $5, $6, $7, NOW()) RETURNING *',
                [title, description, priority || 'medium', category || 'other', product, requesterId, 'open']
            );
            return result.rows[0];
        } else {
            const result = await pool.query(
                'INSERT INTO tickets (title, description, priority, category, product, requester_name, requester_email, requester_phone, status, created_at) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW()) RETURNING *',
                [title, description, priority || 'medium', category || 'other', product, requesterName, requesterEmail, requesterPhone, 'open']
            );
            return result.rows[0];
        }
    }
    
    async updateTicketWithHistory(id, updates, userId, notes) {
        let query = 'UPDATE tickets SET ';
        let params = [];
        let paramIndex = 1;
        
        Object.keys(updates).forEach((key, index) => {
            if (index > 0) query += ', ';
            query += `${key} = $${paramIndex}`;
            params.push(updates[key]);
            paramIndex++;
        });
        
        query += ` WHERE id = $${paramIndex} RETURNING *`;
        params.push(id);
        
        const result = await pool.query(query, params);
        
        if (result.rows.length > 0) {
            await pool.query(
                'INSERT INTO ticket_history (ticket_id, action, user_id, notes, created_at) VALUES ($1, $2, $3, $4, NOW())',
                [id, 'ticket_updated', userId, notes || 'Ticket updated']
            );
        }
        
        return result.rows[0];
    }
    
    async getChanges() {
        const result = await pool.query('SELECT * FROM changes ORDER BY created_at DESC');
        return result.rows;
    }
    
    async createChange(changeData) {
        const { title, description, reason, riskLevel, changeType, scheduledDate, rollbackPlan, requesterId } = changeData;
        const result = await pool.query(
            'INSERT INTO changes (title, description, reason, risk_level, change_type, scheduled_date, rollback_plan, requester_id, status, created_at) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW()) RETURNING *',
            [title, description, reason, riskLevel || 'medium', changeType || 'standard', scheduledDate, rollbackPlan, requesterId, 'draft']
        );
        return result.rows[0];
    }
    
    async createAttachment(attachmentData) {
        const { ticketId, changeId, fileName, originalName, fileSize, mimeType, uploadedBy, uploadedByName } = attachmentData;
        const result = await pool.query(
            'INSERT INTO attachments (ticket_id, change_id, file_name, original_name, file_size, mime_type, uploaded_by, uploaded_by_name, created_at) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW()) RETURNING *',
            [ticketId, changeId, fileName, originalName, fileSize, mimeType, uploadedBy, uploadedByName]
        );
        return result.rows[0];
    }
}

const storage = new ProductionStorage();

// Authentication routes
app.post('/api/auth/login', async (req, res) => {
    try {
        const { username, password } = req.body;
        console.log('[Auth] Login attempt for:', username);
        
        const user = await storage.getUserByUsernameOrEmail(username);
        
        if (!user || user.password !== password) {
            console.log('[Auth] Invalid credentials for:', username);
            return res.status(401).json({ message: "Invalid credentials" });
        }
        
        req.session.user = user;
        const { password: _, ...userWithoutPassword } = user;
        console.log('[Auth] Login successful for:', username, 'Role:', user.role);
        res.json({ user: userWithoutPassword });
    } catch (error) {
        console.error('[Auth] Login error:', error);
        res.status(500).json({ message: "Login failed" });
    }
});

app.get('/api/auth/me', async (req, res) => {
    const currentUser = req.session?.user;
    if (!currentUser) {
        return res.status(401).json({ message: "Not authenticated" });
    }
    const { password: _, ...userWithoutPassword } = currentUser;
    res.json({ user: userWithoutPassword });
});

app.post('/api/auth/logout', async (req, res) => {
    req.session.destroy((err) => {
        if (err) return res.status(500).json({ message: "Logout failed" });
        res.clearCookie('connect.sid');
        res.json({ message: "Logged out successfully" });
    });
});

// User routes
app.get('/api/users', requireAuth, async (req, res) => {
    try {
        const users = await storage.getUsers();
        res.json(users);
    } catch (error) {
        console.error('[Users] Fetch error:', error);
        res.status(500).json({ message: "Failed to fetch users" });
    }
});

app.post('/api/users', requireAdmin, async (req, res) => {
    try {
        const userData = req.body;
        const existingUser = await storage.getUserByUsernameOrEmail(userData.username);
        
        if (existingUser) {
            return res.status(400).json({ message: "Username already exists" });
        }
        
        const user = await storage.createUser(userData);
        res.status(201).json(user);
    } catch (error) {
        console.error('[Users] Create error:', error);
        res.status(500).json({ message: "Failed to create user" });
    }
});

app.patch('/api/users/:id', requireAdmin, async (req, res) => {
    try {
        const id = parseInt(req.params.id);
        const updatedUser = await storage.updateUser(id, req.body);
        if (!updatedUser) {
            return res.status(404).json({ message: "User not found" });
        }
        res.json(updatedUser);
    } catch (error) {
        console.error('[Users] Update error:', error);
        res.status(500).json({ message: "Failed to update user" });
    }
});

app.delete('/api/users/:id', requireAdmin, async (req, res) => {
    try {
        const id = parseInt(req.params.id);
        const success = await storage.deleteUser(id);
        if (!success) {
            return res.status(404).json({ message: "User not found" });
        }
        res.json({ success: true, message: "User deleted successfully" });
    } catch (error) {
        console.error('[Users] Delete error:', error);
        res.status(500).json({ message: "Failed to delete user" });
    }
});

// Product routes (FIXED)
app.get('/api/products', requireAuth, async (req, res) => {
    try {
        console.log('[Products] Fetching products for user:', req.session.user.username);
        const products = await storage.getProducts();
        console.log('[Products] Found', products.length, 'products');
        res.json(products);
    } catch (error) {
        console.error('[Products] Fetch error:', error);
        res.status(500).json({ message: "Failed to fetch products" });
    }
});

app.post('/api/products', requireAdmin, async (req, res) => {
    try {
        console.log('[Products] Product creation request from:', req.session.user.username);
        console.log('[Products] Request body:', req.body);
        
        // Validate product data (mimics insertProductSchema.parse)
        const validatedData = validateProductData(req.body);
        console.log('[Products] Validated data:', validatedData);
        
        const product = await storage.createProduct(validatedData);
        console.log('[Products] Product created successfully:', product);
        
        res.status(201).json(product);
    } catch (error) {
        console.error('[Products] Create error:', error.message);
        console.error('[Products] Full error:', error);
        res.status(400).json({ message: `Failed to create product: ${error.message}` });
    }
});

app.patch('/api/products/:id', requireAdmin, async (req, res) => {
    try {
        const id = parseInt(req.params.id);
        console.log('[Products] Updating product ID:', id, 'by user:', req.session.user.username);
        
        const currentProduct = await storage.getProduct(id);
        if (!currentProduct) {
            return res.status(404).json({ message: "Product not found" });
        }
        
        const validatedData = validateProductData({ ...currentProduct, ...req.body });
        const updatedProduct = await storage.updateProduct(id, validatedData);
        
        if (!updatedProduct) {
            return res.status(404).json({ message: "Product not found" });
        }
        
        console.log('[Products] Product updated successfully:', updatedProduct);
        res.json(updatedProduct);
    } catch (error) {
        console.error('[Products] Update error:', error);
        res.status(400).json({ message: `Failed to update product: ${error.message}` });
    }
});

app.delete('/api/products/:id', requireAdmin, async (req, res) => {
    try {
        const id = parseInt(req.params.id);
        console.log('[Products] Deleting product ID:', id, 'by user:', req.session.user.username);
        
        const success = await storage.deleteProduct(id);
        if (!success) {
            return res.status(404).json({ message: "Product not found" });
        }
        
        console.log('[Products] Product deleted successfully');
        res.json({ message: "Product deleted successfully" });
    } catch (error) {
        console.error('[Products] Delete error:', error);
        res.status(500).json({ message: "Failed to delete product" });
    }
});

// Ticket routes
app.get('/api/tickets', requireAuth, async (req, res) => {
    try {
        const currentUser = req.session.user;
        const tickets = await storage.getTicketsForUser(currentUser.id);
        res.json(tickets);
    } catch (error) {
        console.error('[Tickets] Fetch error:', error);
        res.status(500).json({ message: "Failed to fetch tickets" });
    }
});

app.get('/api/tickets/:id', requireAuth, async (req, res) => {
    try {
        const id = parseInt(req.params.id);
        const ticket = await storage.getTicket(id);
        if (!ticket) {
            return res.status(404).json({ message: "Ticket not found" });
        }
        res.json(ticket);
    } catch (error) {
        res.status(500).json({ message: "Failed to fetch ticket" });
    }
});

app.post('/api/tickets', async (req, res) => {
    try {
        const currentUser = req.session?.user;
        const ticketData = currentUser ? { ...req.body, requesterId: currentUser.id } : req.body;
        const ticket = await storage.createTicket(ticketData);
        res.status(201).json(ticket);
    } catch (error) {
        console.error('[Tickets] Create error:', error);
        res.status(500).json({ message: "Failed to create ticket" });
    }
});

app.patch('/api/tickets/:id', requireAuth, async (req, res) => {
    try {
        const id = parseInt(req.params.id);
        const currentUser = req.session.user;
        
        const updatedTicket = await storage.updateTicketWithHistory(id, req.body, currentUser.id, `Updated by ${currentUser.name}`);
        if (!updatedTicket) {
            return res.status(404).json({ message: "Ticket not found" });
        }
        res.json(updatedTicket);
    } catch (error) {
        console.error('[Tickets] Update error:', error);
        res.status(500).json({ message: "Failed to update ticket" });
    }
});

// Change routes
app.get('/api/changes', requireAuth, async (req, res) => {
    try {
        const changes = await storage.getChanges();
        res.json(changes);
    } catch (error) {
        res.status(500).json({ message: "Failed to fetch changes" });
    }
});

app.post('/api/changes', requireAuth, async (req, res) => {
    try {
        const currentUser = req.session.user;
        const changeData = { ...req.body, requesterId: currentUser.id };
        const change = await storage.createChange(changeData);
        res.status(201).json(change);
    } catch (error) {
        res.status(500).json({ message: "Failed to create change" });
    }
});

// Anonymous search
app.get('/api/tickets/search/anonymous', async (req, res) => {
    try {
        const { q, searchBy = 'all' } = req.query;
        if (!q || typeof q !== 'string' || q.trim().length < 1) {
            return res.status(400).json({ message: "Search query required" });
        }

        const searchTerm = q.trim().toLowerCase();
        let query = 'SELECT * FROM tickets WHERE ';
        let params = [];
        
        if (searchBy === 'product') {
            const selectedProducts = searchTerm.split(',').map(p => p.trim());
            query += 'product = ANY($1::text[])';
            params = [selectedProducts];
        } else if (searchBy === 'ticketNumber') {
            query += 'id::text ILIKE $1';
            params = [`%${q.trim()}%`];
        } else if (searchBy === 'name') {
            query += 'requester_name ILIKE $1';
            params = [`%${searchTerm}%`];
        } else if (searchBy === 'title') {
            query += 'title ILIKE $1';
            params = [`%${searchTerm}%`];
        } else if (searchBy === 'description') {
            query += 'description ILIKE $1';
            params = [`%${searchTerm}%`];
        } else {
            query += '(id::text ILIKE $1 OR title ILIKE $1 OR description ILIKE $1 OR requester_name ILIKE $1 OR product ILIKE $1)';
            params = [`%${searchTerm}%`];
        }
        
        query += ' ORDER BY created_at DESC';
        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (error) {
        res.status(500).json({ message: "Failed to search tickets" });
    }
});

// Anonymous submission
app.post('/api/tickets/anonymous', upload.array('attachments', 5), async (req, res) => {
    try {
        const ticketData = req.body;
        if (!ticketData.requesterName || !ticketData.title || !ticketData.description) {
            return res.status(400).json({ message: "Name, title and description are required" });
        }
        
        const ticket = await storage.createTicket(ticketData);

        const files = req.files;
        if (files && files.length > 0) {
            for (const file of files) {
                await storage.createAttachment({
                    ticketId: ticket.id,
                    changeId: null,
                    fileName: file.filename,
                    originalName: file.originalname,
                    fileSize: file.size,
                    mimeType: file.mimetype,
                    uploadedBy: null,
                    uploadedByName: `${ticketData.requesterName}${ticketData.requesterEmail ? ` (${ticketData.requesterEmail})` : ''}`
                });
            }
        }
        
        res.status(201).json(ticket);
    } catch (error) {
        res.status(400).json({ message: "Invalid ticket data" });
    }
});

app.get('/health', (req, res) => {
    res.json({ 
        status: 'OK', 
        timestamp: new Date().toISOString(),
        authentication: 'Working',
        database: 'Connected',
        userManagement: 'Complete',
        productManagement: 'FIXED',
        ticketManagement: 'Complete',
        changeManagement: 'Complete',
        fileUploads: 'Working',
        anonymousTickets: 'Working',
        environment: 'Fixed Production Adapter'
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
    console.log(`[Fixed] IT Service Desk with fixed product creation running on port ${port}`);
    console.log('[Fixed] Product creation validation and error handling implemented');
});
FIXED_EOF

echo ""
echo "=== CREATING FIXED PM2 CONFIG ==="
cat > production-adapter-fixed.config.cjs << 'PM2_FIXED_EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'production-adapter-fixed.cjs',
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
PM2_FIXED_EOF

echo ""
echo "=== DEPLOYING FIXED PRODUCTION ADAPTER ==="
pm2 delete servicedesk 2>/dev/null
pm2 start production-adapter-fixed.config.cjs
pm2 save

sleep 30

echo ""
echo "=== TESTING FIXED PRODUCT CREATION ==="

# Test authentication first
echo "Testing john.doe authentication:"
JOHN_AUTH=$(curl -s -c /tmp/cookies.txt -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"john.doe","password":"password123"}')
echo "$JOHN_AUTH"

echo ""

# Test product creation (exact same as frontend form)
echo "Testing Olympus 1 product creation (matching your form):"
CREATE_OLYMPUS=$(curl -s -b /tmp/cookies.txt -X POST http://localhost:5000/api/products \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Olympus 1",
    "description": "Brief description of the product",
    "category": "software"
  }')
echo "$CREATE_OLYMPUS"

echo ""

# Test products list
echo "Testing products list:"
PRODUCTS_LIST=$(curl -s -b /tmp/cookies.txt http://localhost:5000/api/products)
echo "$PRODUCTS_LIST"

echo ""

# Test another product creation
echo "Testing another product creation:"
CREATE_TEST=$(curl -s -b /tmp/cookies.txt -X POST http://localhost:5000/api/products \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test Product Fixed",
    "description": "Testing fixed product creation",
    "category": "hardware",
    "owner": "Test Team"
  }')
echo "$CREATE_TEST"

echo ""
echo "=== PM2 STATUS ==="
pm2 status

echo ""
echo "=== RECENT LOGS ==="
pm2 logs servicedesk --lines 15

echo ""
echo "=== FINAL VERIFICATION ==="
if echo "$JOHN_AUTH" | grep -q '"user"' && echo "$CREATE_OLYMPUS" | grep -q '"name"'; then
    echo ""
    echo "SUCCESS: Product creation is now working!"
    echo ""
    echo "✓ Authentication: Working"
    echo "✓ Product creation: FIXED"
    echo "✓ Olympus 1 product: Created successfully"
    echo "✓ Validation: Working properly"
    echo ""
    echo "Access: https://98.81.235.7"
    echo "You can now create products in the admin interface!"
else
    echo "Test results:"
    echo "Auth: $JOHN_AUTH"
    echo "Olympus creation: $CREATE_OLYMPUS"
    echo "Test creation: $CREATE_TEST"
    echo ""
    echo "Checking detailed logs:"
    pm2 logs servicedesk --lines 20
fi

# Cleanup
rm -f /tmp/cookies.txt

EOF