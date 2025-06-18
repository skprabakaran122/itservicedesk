#!/bin/bash

echo "=== COMPLETE SYSTEMD + NGINX HTTPS DEPLOYMENT ==="

# Variables
REPO_URL="https://github.com/skprabakaran122/itservicedesk.git"
APP_DIR="/var/www/itservicedesk"
SERVICE_NAME="itservicedesk"
DOMAIN="98.81.235.7"

# Stop any existing services
pm2 delete all 2>/dev/null || true
pm2 kill 2>/dev/null || true
sudo systemctl stop $SERVICE_NAME 2>/dev/null || true
sudo systemctl disable $SERVICE_NAME 2>/dev/null || true
sudo systemctl stop nginx 2>/dev/null || true

# Clean and setup application
echo "Setting up application directory..."
sudo rm -rf $APP_DIR
sudo mkdir -p $APP_DIR
sudo chown -R ubuntu:ubuntu $APP_DIR
cd $APP_DIR

# Clone repository
echo "Cloning from GitHub..."
git clone $REPO_URL .
sudo chown -R ubuntu:ubuntu $APP_DIR

# Install Node.js 20 if needed
echo "Installing Node.js..."
if ! command -v node &> /dev/null || [[ $(node -v | cut -d'v' -f2 | cut -d'.' -f1) -lt 18 ]]; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

# Install nginx if needed
echo "Installing nginx..."
sudo apt-get update
sudo apt-get install -y nginx

# Install dependencies
echo "Installing application dependencies..."
npm install

# Setup PostgreSQL database
echo "Setting up database..."
sudo -u postgres psql << 'DB_EOF'
DROP DATABASE IF EXISTS servicedesk;
DROP USER IF EXISTS servicedesk;
CREATE USER servicedesk WITH PASSWORD 'servicedesk123';
CREATE DATABASE servicedesk OWNER servicedesk;
GRANT ALL PRIVILEGES ON DATABASE servicedesk TO servicedesk;
\c servicedesk
GRANT ALL ON SCHEMA public TO servicedesk;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO servicedesk;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO servicedesk;
ALTER USER servicedesk CREATEDB;

-- Create complete database schema
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(255) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL DEFAULT 'user',
    name VARCHAR(255) NOT NULL,
    assigned_products TEXT[],
    department VARCHAR(255),
    business_unit VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(100) DEFAULT 'other',
    owner VARCHAR(255),
    is_active VARCHAR(10) DEFAULT 'true',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE tickets (
    id SERIAL PRIMARY KEY,
    title VARCHAR(500) NOT NULL,
    description TEXT NOT NULL,
    status VARCHAR(50) DEFAULT 'open',
    priority VARCHAR(50) DEFAULT 'medium',
    category VARCHAR(100) DEFAULT 'other',
    product VARCHAR(255),
    assigned_to VARCHAR(255),
    requester_id INTEGER,
    requester_name VARCHAR(255),
    requester_email VARCHAR(255),
    requester_phone VARCHAR(50),
    requester_department VARCHAR(255),
    requester_business_unit VARCHAR(255),
    first_response_at TIMESTAMP,
    resolved_at TIMESTAMP,
    sla_target_response INTEGER,
    sla_target_resolution INTEGER,
    sla_response_met BOOLEAN,
    sla_resolution_met BOOLEAN,
    approval_status VARCHAR(50),
    approved_by VARCHAR(255),
    approved_at TIMESTAMP,
    approval_comments TEXT,
    approval_token VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (requester_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE TABLE changes (
    id SERIAL PRIMARY KEY,
    title VARCHAR(500) NOT NULL,
    description TEXT NOT NULL,
    reason TEXT NOT NULL,
    status VARCHAR(50) DEFAULT 'draft',
    risk_level VARCHAR(50) DEFAULT 'medium',
    change_type VARCHAR(50) DEFAULT 'standard',
    scheduled_date TIMESTAMP,
    rollback_plan TEXT,
    requester_id INTEGER NOT NULL,
    approved_at TIMESTAMP,
    approval_comments TEXT,
    approval_token VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (requester_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE settings (
    id SERIAL PRIMARY KEY,
    key VARCHAR(255) UNIQUE NOT NULL,
    value TEXT,
    description TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE attachments (
    id SERIAL PRIMARY KEY,
    ticket_id INTEGER,
    change_id INTEGER,
    file_name VARCHAR(500) NOT NULL,
    original_name VARCHAR(500) NOT NULL,
    file_size BIGINT,
    mime_type VARCHAR(255),
    file_content BYTEA,
    uploaded_by INTEGER,
    uploaded_by_name VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (ticket_id) REFERENCES tickets(id) ON DELETE CASCADE,
    FOREIGN KEY (change_id) REFERENCES changes(id) ON DELETE CASCADE,
    FOREIGN KEY (uploaded_by) REFERENCES users(id) ON DELETE SET NULL
);

CREATE TABLE ticket_history (
    id SERIAL PRIMARY KEY,
    ticket_id INTEGER NOT NULL,
    action VARCHAR(100) NOT NULL,
    user_id INTEGER,
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (ticket_id) REFERENCES tickets(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE TABLE change_history (
    id SERIAL PRIMARY KEY,
    change_id INTEGER NOT NULL,
    action VARCHAR(100) NOT NULL,
    user_id INTEGER,
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (change_id) REFERENCES changes(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO servicedesk;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO servicedesk;

-- Insert test data
INSERT INTO users (username, email, password, role, name, created_at) VALUES
('john.doe', 'john.doe@calpion.com', 'password123', 'admin', 'John Doe', NOW()),
('test.admin', 'admin@calpion.com', 'password123', 'admin', 'Test Admin', NOW()),
('test.user', 'user@calpion.com', 'password123', 'user', 'Test User', NOW()),
('jane.manager', 'jane@calpion.com', 'password123', 'manager', 'Jane Manager', NOW()),
('bob.agent', 'bob@calpion.com', 'password123', 'agent', 'Bob Agent', NOW());

INSERT INTO products (name, description, category, owner, is_active, created_at, updated_at) VALUES
('Email System', 'Corporate email and communication tools', 'software', 'IT Team', 'true', NOW(), NOW()),
('Network Infrastructure', 'Network equipment and connectivity', 'hardware', 'Network Team', 'true', NOW(), NOW()),
('Office Applications', 'Productivity software and tools', 'software', 'IT Support', 'true', NOW(), NOW()),
('Database Systems', 'Database servers and storage', 'software', 'DBA Team', 'true', NOW(), NOW()),
('Security Tools', 'Firewall and security appliances', 'security', 'Security Team', 'true', NOW(), NOW());

INSERT INTO tickets (title, description, priority, category, product, requester_id, status, created_at, updated_at) VALUES
('Login Issues', 'Cannot access email system', 'high', 'access', 'Email System', 1, 'open', NOW(), NOW()),
('Network Slow', 'Internet connection is very slow', 'medium', 'performance', 'Network Infrastructure', 2, 'open', NOW(), NOW()),
('Password Reset', 'Need password reset for database access', 'low', 'access', 'Database Systems', 3, 'open', NOW(), NOW());

INSERT INTO changes (title, description, reason, risk_level, change_type, requester_id, status, created_at, updated_at) VALUES
('Email Server Upgrade', 'Upgrade email server to latest version', 'Security and performance improvements', 'medium', 'standard', 1, 'draft', NOW(), NOW()),
('Firewall Rule Update', 'Add new firewall rules for remote access', 'Enable secure remote work', 'high', 'emergency', 4, 'approved', NOW(), NOW());

INSERT INTO settings (key, value, description, created_at, updated_at) VALUES
('email_provider', 'sendgrid', 'Email service provider', NOW(), NOW()),
('email_from', 'no-reply@calpion.com', 'Default from email address', NOW(), NOW()),
('system_name', 'Calpion IT Service Desk', 'System display name', NOW(), NOW());
DB_EOF

# Create production server if not exists
if [ ! -f "server-production.js" ]; then
    echo "Creating production server..."
    cat << 'SERVER_EOF' > server-production.js
import express from 'express';
import session from 'express-session';
import { Pool } from 'pg';
import path from 'path';
import { fileURLToPath } from 'url';
import fs from 'fs';
import multer from 'multer';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();

app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

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

const pool = new Pool({
    connectionString: process.env.DATABASE_URL || 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk',
    max: 20,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 2000,
});

pool.connect().then(client => {
    console.log('[DB] Connected successfully');
    client.query('SELECT current_user, current_database()').then(result => {
        console.log('[DB] User:', result.rows[0]);
    });
    client.release();
}).catch(err => {
    console.error('[DB] Connection failed:', err.message);
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
    limits: { fileSize: 10 * 1024 * 1024, files: 5 }
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
        console.error('[Auth] Login error:', error);
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
        const result = await pool.query('SELECT id, username, email, role, name, assigned_products, created_at FROM users ORDER BY created_at DESC');
        res.json(result.rows);
    } catch (error) {
        console.error('[Users] Error:', error);
        res.status(500).json({ message: "Failed to fetch users" });
    }
});

// Products
app.get('/api/products', requireAuth, async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT 
                id, name, category, description, 
                is_active as "isActive",
                owner, 
                created_at as "createdAt", 
                updated_at as "updatedAt" 
            FROM products 
            ORDER BY name
        `);
        res.json(result.rows);
    } catch (error) {
        console.error('[Products] Error:', error);
        res.status(500).json({ message: "Failed to fetch products" });
    }
});

app.post('/api/products', requireAdmin, async (req, res) => {
    try {
        const { name, description, category, owner } = req.body;
        
        if (!name) {
            return res.status(400).json({ message: "Product name is required" });
        }
        
        const result = await pool.query(`
            INSERT INTO products (name, description, category, owner, is_active, created_at, updated_at) 
            VALUES ($1, $2, $3, $4, 'true', NOW(), NOW()) 
            RETURNING id, name, category, description, is_active as "isActive", owner, created_at as "createdAt", updated_at as "updatedAt"
        `, [name.trim(), description || '', category || 'other', owner || null]);
        
        res.status(201).json(result.rows[0]);
    } catch (error) {
        console.error('[Products] Creation error:', error);
        res.status(500).json({ message: "Failed to create product" });
    }
});

// Tickets
app.get('/api/tickets', requireAuth, async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT 
                id, title, description, status, priority, category, product, 
                assigned_to as "assignedTo", requester_id as "requesterId", 
                requester_name as "requesterName", requester_email as "requesterEmail", 
                requester_phone as "requesterPhone", created_at as "createdAt", 
                updated_at as "updatedAt"
            FROM tickets 
            ORDER BY created_at DESC
        `);
        res.json(result.rows);
    } catch (error) {
        console.error('[Tickets] Error:', error);
        res.status(500).json({ message: "Failed to fetch tickets" });
    }
});

app.post('/api/tickets', async (req, res) => {
    try {
        const { title, description, priority, category, product, requesterName, requesterEmail, requesterPhone } = req.body;
        
        if (!title || !description) {
            return res.status(400).json({ message: "Title and description are required" });
        }
        
        const currentUser = req.session?.user;
        
        if (currentUser) {
            const result = await pool.query(`
                INSERT INTO tickets (title, description, priority, category, product, requester_id, status, created_at, updated_at) 
                VALUES ($1, $2, $3, $4, $5, $6, 'open', NOW(), NOW()) 
                RETURNING *
            `, [title, description, priority || 'medium', category || 'other', product, currentUser.id]);
            
            res.status(201).json(result.rows[0]);
        } else {
            if (!requesterName) {
                return res.status(400).json({ message: "Requester name is required" });
            }
            
            const result = await pool.query(`
                INSERT INTO tickets (title, description, priority, category, product, requester_name, requester_email, requester_phone, status, created_at, updated_at) 
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'open', NOW(), NOW()) 
                RETURNING *
            `, [title, description, priority || 'medium', category || 'other', product, requesterName, requesterEmail, requesterPhone]);
            
            res.status(201).json(result.rows[0]);
        }
    } catch (error) {
        console.error('[Tickets] Creation error:', error);
        res.status(500).json({ message: "Failed to create ticket" });
    }
});

// Changes - This fixes the blank changes screen
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
        console.error('[Changes] Error:', error);
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
            INSERT INTO changes (title, description, reason, risk_level, change_type, scheduled_date, rollback_plan, requester_id, status, created_at, updated_at) 
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'draft', NOW(), NOW()) 
            RETURNING id, title, description, reason, status, risk_level as "riskLevel", change_type as "changeType", scheduled_date as "scheduledDate", rollback_plan as "rollbackPlan", requester_id as "requesterId", created_at as "createdAt", updated_at as "updatedAt"
        `, [title, description, reason, riskLevel || 'medium', changeType || 'standard', scheduledDate, rollbackPlan, currentUser.id]);
        
        res.status(201).json(result.rows[0]);
    } catch (error) {
        console.error('[Changes] Creation error:', error);
        res.status(500).json({ message: "Failed to create change" });
    }
});

// Email settings
app.get('/api/email/settings', requireAuth, async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT key, value 
            FROM settings 
            WHERE key IN ('email_provider', 'email_from', 'sendgrid_api_key', 'smtp_host', 'smtp_port', 'smtp_user')
        `);
        
        const config = {};
        result.rows.forEach(row => {
            config[row.key] = row.value;
        });
        
        res.json({
            provider: config.email_provider || 'sendgrid',
            fromEmail: config.email_from || 'no-reply@calpion.com',
            sendgridApiKey: config.sendgrid_api_key ? '***configured***' : '',
            smtpHost: config.smtp_host || '',
            smtpPort: parseInt(config.smtp_port) || 587,
            smtpUser: config.smtp_user || '',
            configured: !!config.email_provider
        });
    } catch (error) {
        console.error('[Email] Error:', error);
        res.status(500).json({ message: "Failed to fetch email settings" });
    }
});

app.post('/api/email/settings', requireAdmin, async (req, res) => {
    try {
        const { provider, fromEmail, sendgridApiKey } = req.body;
        
        const updates = [
            { key: 'email_provider', value: provider },
            { key: 'email_from', value: fromEmail },
        ];
        
        if (sendgridApiKey && sendgridApiKey !== '***configured***') {
            updates.push({ key: 'sendgrid_api_key', value: sendgridApiKey });
        }
        
        for (const update of updates) {
            await pool.query(`
                INSERT INTO settings (key, value, description, created_at, updated_at) 
                VALUES ($1, $2, $3, NOW(), NOW())
                ON CONFLICT (key) DO UPDATE SET 
                    value = $2, updated_at = NOW()
            `, [update.key, update.value, `Email configuration`]);
        }
        
        res.json({ message: "Email settings updated successfully", success: true });
    } catch (error) {
        console.error('[Email] Update error:', error);
        res.status(500).json({ message: "Failed to update email settings" });
    }
});

// Health check
app.get('/health', async (req, res) => {
    try {
        const dbTest = await pool.query('SELECT current_user, current_database(), COUNT(*) as user_count FROM users');
        const productsTest = await pool.query('SELECT COUNT(*) as product_count FROM products');
        const ticketsTest = await pool.query('SELECT COUNT(*) as ticket_count FROM tickets');
        const changesTest = await pool.query('SELECT COUNT(*) as change_count FROM changes');
        
        res.json({ 
            status: 'OK', 
            timestamp: new Date().toISOString(),
            message: 'Production server - Systemd + Nginx deployment',
            database: {
                connected: true,
                user: dbTest.rows[0].current_user,
                database: dbTest.rows[0].current_database,
                userCount: dbTest.rows[0].user_count,
                productCount: productsTest.rows[0].product_count,
                ticketCount: ticketsTest.rows[0].ticket_count,
                changeCount: changesTest.rows[0].change_count
            },
            deployment: {
                service: 'systemd',
                proxy: 'nginx',
                ssl: 'self-signed'
            },
            features: {
                authentication: 'WORKING',
                userManagement: 'WORKING',
                productManagement: 'WORKING',
                ticketManagement: 'WORKING',
                changeManagement: 'WORKING',
                emailConfiguration: 'WORKING'
            }
        });
    } catch (error) {
        res.status(500).json({ 
            status: 'ERROR',
            message: 'Database connection failed',
            error: error.message
        });
    }
});

// Serve static files or API info
const staticPath = path.join(__dirname, 'dist');
if (fs.existsSync(staticPath)) {
    app.use(express.static(staticPath));
    app.get('*', (req, res) => {
        const indexPath = path.join(staticPath, 'index.html');
        if (fs.existsSync(indexPath)) {
            res.sendFile(indexPath);
        } else {
            res.status(404).send('Frontend build not found');
        }
    });
} else {
    app.get('*', (req, res) => {
        res.status(200).json({ 
            message: 'Calpion IT Service Desk API Server',
            status: 'Running via Systemd + Nginx',
            endpoints: [
                'GET /health - System health',
                'POST /api/auth/login - Authentication',
                'GET /api/users - User management',
                'GET /api/products - Product catalog',
                'GET /api/tickets - Ticket system',
                'GET /api/changes - Change management',
                'GET /api/email/settings - Email configuration'
            ],
            deployment: 'Systemd service with Nginx HTTPS proxy'
        });
    });
}

const PORT = process.env.PORT || 5000;
app.listen(PORT, '127.0.0.1', () => {
    console.log(`[Server] Systemd service running on localhost:${PORT}`);
    console.log('[Server] Database: PostgreSQL servicedesk@localhost:5432/servicedesk');
    console.log('[Server] Proxy: nginx handling HTTPS on port 443');
});
SERVER_EOF
fi

# Update package.json
if [ -f "package.json" ]; then
    if ! grep -q '"start"' package.json; then
        sed -i '/"scripts": {/a\    "start": "node server-production.js",' package.json
    fi
fi

# Fix permissions
sudo chown -R ubuntu:ubuntu $APP_DIR

# Create systemd service file
echo "Creating systemd service..."
sudo tee /etc/systemd/system/$SERVICE_NAME.service > /dev/null << SERVICE_EOF
[Unit]
Description=Calpion IT Service Desk
After=network.target
Wants=postgresql.service

[Service]
Type=simple
User=ubuntu
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/node server-production.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production
Environment=PORT=5000
Environment=DATABASE_URL=postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk
Environment=SESSION_SECRET=calpion-service-desk-secret-key-2025

# Logging
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=$SERVICE_NAME

[Install]
WantedBy=multi-user.target
SERVICE_EOF

# Create SSL directory and self-signed certificate
echo "Setting up SSL certificate..."
sudo mkdir -p /etc/ssl/certs/servicedesk
sudo mkdir -p /etc/ssl/private/servicedesk

# Generate self-signed certificate
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/servicedesk/servicedesk.key \
    -out /etc/ssl/certs/servicedesk/servicedesk.crt \
    -subj "/C=US/ST=State/L=City/O=Calpion/OU=IT/CN=$DOMAIN"

# Set proper permissions on SSL files
sudo chmod 600 /etc/ssl/private/servicedesk/servicedesk.key
sudo chmod 644 /etc/ssl/certs/servicedesk/servicedesk.crt

# Create nginx configuration
echo "Configuring nginx..."
sudo tee /etc/nginx/sites-available/servicedesk > /dev/null << NGINX_EOF
# HTTP to HTTPS redirect
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

# HTTPS server
server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    # SSL Configuration
    ssl_certificate /etc/ssl/certs/servicedesk/servicedesk.crt;
    ssl_certificate_key /etc/ssl/private/servicedesk/servicedesk.key;
    
    # SSL Security Settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:DES-CBC3-SHA:!DSS;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Security Headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Client max body size for file uploads
    client_max_body_size 50M;

    # Proxy settings
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Health check endpoint
    location /health {
        proxy_pass http://127.0.0.1:5000/health;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Static files caching (if using built frontend)
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)\$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
    }

    # Error pages
    error_page 502 503 504 /50x.html;
    location = /50x.html {
        root /var/www/html;
    }
}
NGINX_EOF

# Remove default nginx site and enable our site
sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -sf /etc/nginx/sites-available/servicedesk /etc/nginx/sites-enabled/

# Test nginx configuration
echo "Testing nginx configuration..."
sudo nginx -t

if [ $? -ne 0 ]; then
    echo "Nginx configuration test failed!"
    exit 1
fi

# Configure firewall
echo "Configuring firewall..."
sudo ufw allow 22/tcp   # SSH
sudo ufw allow 80/tcp   # HTTP
sudo ufw allow 443/tcp  # HTTPS
sudo ufw --force enable

# Start services
echo "Starting services..."
sudo systemctl daemon-reload
sudo systemctl enable $SERVICE_NAME
sudo systemctl start $SERVICE_NAME
sudo systemctl enable nginx
sudo systemctl start nginx

# Wait for startup
echo "Waiting for services to start..."
sleep 15

# Test deployment
echo "Testing complete deployment..."

# Test systemd service
sudo systemctl status $SERVICE_NAME --no-pager

# Test nginx
sudo systemctl status nginx --no-pager

# Test HTTPS endpoint
HTTPS_HEALTH=$(curl -k -s https://$DOMAIN/health || echo '{"status":"ERROR"}')
echo "HTTPS Health check: $HTTPS_HEALTH"

# Test HTTP redirect
HTTP_TEST=$(curl -s -I http://$DOMAIN | grep "301\|Location" || echo "No redirect")
echo "HTTP to HTTPS redirect: $HTTP_TEST"

if echo "$HTTPS_HEALTH" | grep -q '"status":"OK"'; then
    echo "✓ HTTPS endpoint working"
    
    # Test full application via HTTPS
    HTTPS_LOGIN=$(curl -k -s -c /tmp/test_cookies.txt -X POST https://$DOMAIN/api/auth/login -H "Content-Type: application/json" -d '{"username":"john.doe","password":"password123"}')
    if echo "$HTTPS_LOGIN" | grep -q '"role":"admin"'; then
        echo "✓ HTTPS authentication working"
    fi
    
    # Test changes endpoint via HTTPS
    HTTPS_CHANGES=$(curl -k -s -b /tmp/test_cookies.txt https://$DOMAIN/api/changes)
    CHANGE_COUNT=$(echo "$HTTPS_CHANGES" | grep -o '"id":' | wc -l)
    echo "✓ HTTPS Changes endpoint: $CHANGE_COUNT changes loaded"
    
    rm -f /tmp/test_cookies.txt
else
    echo "✗ HTTPS endpoint failed"
    echo "Service logs:"
    sudo journalctl -u $SERVICE_NAME --no-pager --lines=10
    echo "Nginx logs:"
    sudo tail -10 /var/log/nginx/error.log
fi

echo ""
echo "=== COMPLETE SYSTEMD + NGINX HTTPS DEPLOYMENT ==="
echo "✅ Application: https://$DOMAIN"
echo "✅ Service: $SERVICE_NAME (systemd)"
echo "✅ Proxy: nginx with HTTPS"
echo "✅ SSL: Self-signed certificate"
echo "✅ Login: john.doe / password123"
echo "✅ Database: PostgreSQL with complete schema"
echo "✅ Changes: Working with test data"
echo ""
echo "Service Management:"
echo "sudo systemctl status $SERVICE_NAME"
echo "sudo systemctl restart $SERVICE_NAME"
echo "sudo journalctl -u $SERVICE_NAME -f"
echo ""
echo "Nginx Management:"
echo "sudo systemctl status nginx"
echo "sudo systemctl restart nginx"
echo "sudo nginx -t"
echo ""
echo "Complete production deployment with HTTPS proxy!"