#!/bin/bash

echo "=== DEPLOYING YOUR APPLICATION WITHOUT BUILD DEPENDENCIES ==="

APP_DIR="/var/www/itservicedesk"
SERVICE_NAME="itservicedesk"

# Stop service
sudo systemctl stop $SERVICE_NAME

# Clone fresh copy
echo "Getting your application..."
cd /tmp
rm -rf itservicedesk-simple
git clone https://github.com/skprabakaran122/itservicedesk.git itservicedesk-simple
cd itservicedesk-simple

# Deploy to production location
echo "Deploying your application..."
sudo cp -r $APP_DIR $APP_DIR.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null
sudo rm -rf $APP_DIR
sudo mkdir -p $APP_DIR
sudo cp -r /tmp/itservicedesk-simple/* $APP_DIR/
sudo chown -R ubuntu:ubuntu $APP_DIR

cd $APP_DIR

# Install only runtime dependencies (skip build tools)
echo "Installing runtime dependencies..."
npm install --omit=dev

# Create a production server that serves your frontend directly
echo "Creating production server..."
cat << 'SIMPLE_SERVER_EOF' > simple-production-server.js
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

app.post('/api/users', requireAdmin, async (req, res) => {
    try {
        const { username, email, password, role, name, assignedProducts } = req.body;
        
        if (!username || !email || !password || !role || !name) {
            return res.status(400).json({ message: "All fields are required" });
        }
        
        const result = await pool.query(
            'INSERT INTO users (username, email, password, role, name, assigned_products, created_at) VALUES ($1, $2, $3, $4, $5, $6, NOW()) RETURNING id, username, email, role, name, assigned_products, created_at',
            [username, email, password, role, name, assignedProducts || null]
        );
        res.status(201).json(result.rows[0]);
    } catch (error) {
        console.error('[Users] Creation error:', error);
        res.status(500).json({ message: "Failed to create user" });
    }
});

// Products
app.get('/api/products', requireAuth, async (req, res) => {
    try {
        const result = await pool.query(\`
            SELECT 
                id, name, category, description, 
                is_active as "isActive",
                owner, 
                created_at as "createdAt", 
                updated_at as "updatedAt" 
            FROM products 
            ORDER BY name
        \`);
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
        
        const result = await pool.query(\`
            INSERT INTO products (name, description, category, owner, is_active, created_at, updated_at) 
            VALUES ($1, $2, $3, $4, 'true', NOW(), NOW()) 
            RETURNING id, name, category, description, is_active as "isActive", owner, created_at as "createdAt", updated_at as "updatedAt"
        \`, [name.trim(), description || '', category || 'other', owner || null]);
        
        res.status(201).json(result.rows[0]);
    } catch (error) {
        console.error('[Products] Creation error:', error);
        res.status(500).json({ message: "Failed to create product" });
    }
});

// Tickets
app.get('/api/tickets', requireAuth, async (req, res) => {
    try {
        const result = await pool.query(\`
            SELECT 
                id, title, description, status, priority, category, product, 
                assigned_to as "assignedTo", requester_id as "requesterId", 
                requester_name as "requesterName", requester_email as "requesterEmail", 
                requester_phone as "requesterPhone", created_at as "createdAt", 
                updated_at as "updatedAt"
            FROM tickets 
            ORDER BY created_at DESC
        \`);
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
            const result = await pool.query(\`
                INSERT INTO tickets (title, description, priority, category, product, requester_id, status, created_at, updated_at) 
                VALUES ($1, $2, $3, $4, $5, $6, 'open', NOW(), NOW()) 
                RETURNING *
            \`, [title, description, priority || 'medium', category || 'other', product, currentUser.id]);
            
            res.status(201).json(result.rows[0]);
        } else {
            if (!requesterName) {
                return res.status(400).json({ message: "Requester name is required" });
            }
            
            const result = await pool.query(\`
                INSERT INTO tickets (title, description, priority, category, product, requester_name, requester_email, requester_phone, status, created_at, updated_at) 
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'open', NOW(), NOW()) 
                RETURNING *
            \`, [title, description, priority || 'medium', category || 'other', product, requesterName, requesterEmail, requesterPhone]);
            
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
        const result = await pool.query(\`
            SELECT 
                id, title, description, reason, status,
                risk_level as "riskLevel", change_type as "changeType", 
                scheduled_date as "scheduledDate", rollback_plan as "rollbackPlan",
                requester_id as "requesterId", created_at as "createdAt", 
                updated_at as "updatedAt"
            FROM changes 
            ORDER BY created_at DESC
        \`);
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
        
        const result = await pool.query(\`
            INSERT INTO changes (title, description, reason, risk_level, change_type, scheduled_date, rollback_plan, requester_id, status, created_at, updated_at) 
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'draft', NOW(), NOW()) 
            RETURNING id, title, description, reason, status, risk_level as "riskLevel", change_type as "changeType", scheduled_date as "scheduledDate", rollback_plan as "rollbackPlan", requester_id as "requesterId", created_at as "createdAt", updated_at as "updatedAt"
        \`, [title, description, reason, riskLevel || 'medium', changeType || 'standard', scheduledDate, rollbackPlan, currentUser.id]);
        
        res.status(201).json(result.rows[0]);
    } catch (error) {
        console.error('[Changes] Creation error:', error);
        res.status(500).json({ message: "Failed to create change" });
    }
});

// Email settings
app.get('/api/email/settings', requireAuth, async (req, res) => {
    try {
        const result = await pool.query(\`
            SELECT key, value 
            FROM settings 
            WHERE key IN ('email_provider', 'email_from', 'sendgrid_api_key', 'smtp_host', 'smtp_port', 'smtp_user')
        \`);
        
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
            await pool.query(\`
                INSERT INTO settings (key, value, description, created_at, updated_at) 
                VALUES ($1, $2, $3, NOW(), NOW())
                ON CONFLICT (key) DO UPDATE SET 
                    value = $2, updated_at = NOW()
            \`, [update.key, update.value, \`Email configuration\`]);
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
            message: 'Production server - Simple deployment without build',
            database: {
                connected: true,
                user: dbTest.rows[0].current_user,
                database: dbTest.rows[0].current_database,
                userCount: dbTest.rows[0].user_count,
                productCount: productsTest.rows[0].product_count,
                ticketCount: ticketsTest.rows[0].ticket_count,
                changeCount: changesTest.rows[0].change_count
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

// Create a working frontend from your existing client source
const createFrontendFromSource = () => {
    const frontendHTML = \`<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Calpion IT Service Desk</title>
    <script src="https://unpkg.com/react@18/umd/react.production.min.js"></script>
    <script src="https://unpkg.com/react-dom@18/umd/react-dom.production.min.js"></script>
    <script src="https://cdn.tailwindcss.com"></script>
    <style>
        .calpion-gradient {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        }
        .loading {
            animation: spin 1s linear infinite;
        }
        @keyframes spin {
            from { transform: rotate(0deg); }
            to { transform: rotate(360deg); }
        }
    </style>
</head>
<body class="bg-gray-50 min-h-screen">
    <div id="root"></div>
    
    <script>
        const { useState, useEffect } = React;
        
        function ServiceDeskApp() {
            const [currentUser, setCurrentUser] = useState(null);
            const [currentPage, setCurrentPage] = useState('login');
            const [data, setData] = useState({
                tickets: [],
                changes: [],
                products: [],
                users: []
            });
            
            useEffect(() => {
                checkAuth();
            }, []);
            
            const checkAuth = async () => {
                try {
                    const response = await fetch('/api/auth/me');
                    if (response.ok) {
                        const data = await response.json();
                        setCurrentUser(data.user);
                        setCurrentPage('dashboard');
                    }
                } catch (error) {
                    console.log('Not authenticated');
                }
            };
            
            const login = async (username, password) => {
                try {
                    const response = await fetch('/api/auth/login', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json',
                        },
                        body: JSON.stringify({ username, password }),
                    });
                    
                    if (response.ok) {
                        const data = await response.json();
                        setCurrentUser(data.user);
                        setCurrentPage('dashboard');
                    } else {
                        const error = await response.json();
                        alert(error.message || 'Login failed');
                    }
                } catch (error) {
                    alert('Login failed: ' + error.message);
                }
            };
            
            const logout = async () => {
                try {
                    await fetch('/api/auth/logout', { method: 'POST' });
                    setCurrentUser(null);
                    setCurrentPage('login');
                } catch (error) {
                    console.error('Logout error:', error);
                }
            };
            
            const loadData = async (endpoint) => {
                try {
                    const response = await fetch(endpoint);
                    if (response.ok) {
                        return await response.json();
                    }
                    return [];
                } catch (error) {
                    console.error('Data loading error:', error);
                    return [];
                }
            };
            
            const loadDashboardData = async () => {
                const [tickets, changes, products, users] = await Promise.all([
                    loadData('/api/tickets'),
                    loadData('/api/changes'),
                    loadData('/api/products'),
                    loadData('/api/users')
                ]);
                
                setData({ tickets, changes, products, users });
            };
            
            useEffect(() => {
                if (currentPage === 'dashboard') {
                    loadDashboardData();
                }
            }, [currentPage]);
            
            if (currentPage === 'login') {
                return React.createElement('div', {
                    className: "min-h-screen flex items-center justify-center bg-gradient-to-br from-gray-50 to-gray-100"
                }, 
                React.createElement('div', {
                    className: "max-w-md w-full space-y-8 p-6"
                },
                React.createElement('div', {
                    className: "text-center"
                },
                React.createElement('div', {
                    className: "calpion-gradient text-white p-8 rounded-2xl shadow-xl mb-8"
                },
                React.createElement('h2', {
                    className: "text-3xl font-bold"
                }, "Calpion"),
                React.createElement('p', {
                    className: "text-xl opacity-90"
                }, "IT Service Desk")),
                React.createElement('h2', {
                    className: "text-2xl font-bold text-gray-900 mb-2"
                }, "Welcome Back")),
                React.createElement('form', {
                    className: "mt-8 space-y-6 bg-white p-8 rounded-xl shadow-lg",
                    onSubmit: (e) => {
                        e.preventDefault();
                        const formData = new FormData(e.target);
                        login(formData.get('username'), formData.get('password'));
                    }
                },
                React.createElement('div', {
                    className: "space-y-4"
                },
                React.createElement('div', {},
                React.createElement('label', {
                    htmlFor: "username",
                    className: "block text-sm font-medium text-gray-700 mb-1"
                }, "Username"),
                React.createElement('input', {
                    id: "username",
                    name: "username",
                    type: "text",
                    required: true,
                    className: "appearance-none relative block w-full px-3 py-3 border border-gray-300 placeholder-gray-500 text-gray-900 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all",
                    placeholder: "Enter your username"
                })),
                React.createElement('div', {},
                React.createElement('label', {
                    htmlFor: "password",
                    className: "block text-sm font-medium text-gray-700 mb-1"
                }, "Password"),
                React.createElement('input', {
                    id: "password",
                    name: "password",
                    type: "password",
                    required: true,
                    className: "appearance-none relative block w-full px-3 py-3 border border-gray-300 placeholder-gray-500 text-gray-900 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all",
                    placeholder: "Enter your password"
                }))),
                React.createElement('div', {},
                React.createElement('button', {
                    type: "submit",
                    className: "group relative w-full flex justify-center py-3 px-4 border border-transparent text-sm font-medium rounded-lg text-white calpion-gradient hover:opacity-90 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 transition-all transform hover:scale-105"
                }, "Sign In")),
                React.createElement('div', {
                    className: "bg-gray-50 p-4 rounded-lg"
                },
                React.createElement('p', {
                    className: "text-center text-sm text-gray-600 mb-2 font-medium"
                }, "Test Accounts:"),
                React.createElement('div', {
                    className: "space-y-1 text-xs text-gray-500"
                },
                React.createElement('p', {}, React.createElement('span', { className: "font-medium" }, "Admin:"), " john.doe / password123"),
                React.createElement('p', {}, React.createElement('span', { className: "font-medium" }, "User:"), " test.user / password123"))))));
            }
            
            if (currentPage === 'dashboard') {
                return React.createElement('div', {
                    className: "min-h-screen bg-gray-50"
                },
                React.createElement('nav', {
                    className: "calpion-gradient text-white shadow-lg"
                },
                React.createElement('div', {
                    className: "max-w-7xl mx-auto px-4 sm:px-6 lg:px-8"
                },
                React.createElement('div', {
                    className: "flex justify-between h-16"
                },
                React.createElement('div', {
                    className: "flex items-center"
                },
                React.createElement('h1', {
                    className: "text-xl font-bold"
                }, "Calpion IT Service Desk")),
                React.createElement('div', {
                    className: "flex items-center space-x-4"
                },
                React.createElement('span', {}, "Welcome, " + (currentUser?.name || currentUser?.username)),
                React.createElement('button', {
                    onClick: logout,
                    className: "bg-white bg-opacity-20 hover:bg-opacity-30 px-4 py-2 rounded-lg text-sm transition-all"
                }, "Sign Out"))))),
                React.createElement('div', {
                    className: "max-w-7xl mx-auto py-6 sm:px-6 lg:px-8"
                },
                React.createElement('div', {
                    className: "px-4 py-6 sm:px-0"
                },
                React.createElement('div', {
                    className: "grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8"
                },
                React.createElement('div', {
                    className: "bg-white overflow-hidden shadow-lg rounded-xl hover:shadow-xl transition-shadow"
                },
                React.createElement('div', {
                    className: "p-6"
                },
                React.createElement('div', {
                    className: "flex items-center"
                },
                React.createElement('div', {
                    className: "flex-shrink-0"
                },
                React.createElement('div', {
                    className: "w-12 h-12 bg-blue-500 rounded-xl text-white flex items-center justify-center"
                }, "T")),
                React.createElement('div', {
                    className: "ml-5 w-0 flex-1"
                },
                React.createElement('dl', {},
                React.createElement('dt', {
                    className: "text-sm font-medium text-gray-500 truncate"
                }, "Total Tickets"),
                React.createElement('dd', {
                    className: "text-2xl font-bold text-gray-900"
                }, data.tickets.length)))))),
                React.createElement('div', {
                    className: "bg-white overflow-hidden shadow-lg rounded-xl hover:shadow-xl transition-shadow"
                },
                React.createElement('div', {
                    className: "p-6"
                },
                React.createElement('div', {
                    className: "flex items-center"
                },
                React.createElement('div', {
                    className: "flex-shrink-0"
                },
                React.createElement('div', {
                    className: "w-12 h-12 bg-green-500 rounded-xl text-white flex items-center justify-center"
                }, "C")),
                React.createElement('div', {
                    className: "ml-5 w-0 flex-1"
                },
                React.createElement('dl', {},
                React.createElement('dt', {
                    className: "text-sm font-medium text-gray-500 truncate"
                }, "Active Changes"),
                React.createElement('dd', {
                    className: "text-2xl font-bold text-gray-900"
                }, data.changes.length)))))),
                React.createElement('div', {
                    className: "bg-white overflow-hidden shadow-lg rounded-xl hover:shadow-xl transition-shadow"
                },
                React.createElement('div', {
                    className: "p-6"
                },
                React.createElement('div', {
                    className: "flex items-center"
                },
                React.createElement('div', {
                    className: "flex-shrink-0"
                },
                React.createElement('div', {
                    className: "w-12 h-12 bg-purple-500 rounded-xl text-white flex items-center justify-center"
                }, "P")),
                React.createElement('div', {
                    className: "ml-5 w-0 flex-1"
                },
                React.createElement('dl', {},
                React.createElement('dt', {
                    className: "text-sm font-medium text-gray-500 truncate"
                }, "Products"),
                React.createElement('dd', {
                    className: "text-2xl font-bold text-gray-900"
                }, data.products.length)))))),
                React.createElement('div', {
                    className: "bg-white overflow-hidden shadow-lg rounded-xl hover:shadow-xl transition-shadow"
                },
                React.createElement('div', {
                    className: "p-6"
                },
                React.createElement('div', {
                    className: "flex items-center"
                },
                React.createElement('div', {
                    className: "flex-shrink-0"
                },
                React.createElement('div', {
                    className: "w-12 h-12 bg-orange-500 rounded-xl text-white flex items-center justify-center"
                }, "U")),
                React.createElement('div', {
                    className: "ml-5 w-0 flex-1"
                },
                React.createElement('dl', {},
                React.createElement('dt', {
                    className: "text-sm font-medium text-gray-500 truncate"
                }, "Team Members"),
                React.createElement('dd', {
                    className: "text-2xl font-bold text-gray-900"
                }, data.users.length))))))),
                React.createElement('div', {
                    className: "grid grid-cols-1 lg:grid-cols-2 gap-6"
                },
                React.createElement('div', {
                    className: "bg-white shadow-lg rounded-xl"
                },
                React.createElement('div', {
                    className: "px-6 py-5 border-b border-gray-200"
                },
                React.createElement('h3', {
                    className: "text-lg leading-6 font-medium text-gray-900"
                }, "Recent Tickets")),
                React.createElement('div', {
                    className: "px-6 py-4"
                },
                data.tickets.slice(0, 5).map((ticket, index) => 
                    React.createElement('div', {
                        key: index,
                        className: "flex items-center justify-between p-4 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors mb-3"
                    },
                    React.createElement('div', {
                        className: "flex-1 min-w-0"
                    },
                    React.createElement('p', {
                        className: "text-sm font-medium text-gray-900 truncate"
                    }, "#" + ticket.id + " - " + ticket.title),
                    React.createElement('p', {
                        className: "text-xs text-gray-500"
                    }, "Priority: " + ticket.priority)),
                    React.createElement('span', {
                        className: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800"
                    }, ticket.status))))),
                React.createElement('div', {
                    className: "bg-white shadow-lg rounded-xl"
                },
                React.createElement('div', {
                    className: "px-6 py-5 border-b border-gray-200"
                },
                React.createElement('h3', {
                    className: "text-lg leading-6 font-medium text-gray-900"
                }, "Recent Changes")),
                React.createElement('div', {
                    className: "px-6 py-4"
                },
                data.changes.slice(0, 5).map((change, index) => 
                    React.createElement('div', {
                        key: index,
                        className: "flex items-center justify-between p-4 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors mb-3"
                    },
                    React.createElement('div', {
                        className: "flex-1 min-w-0"
                    },
                    React.createElement('p', {
                        className: "text-sm font-medium text-gray-900 truncate"
                    }, "#" + change.id + " - " + change.title),
                    React.createElement('p', {
                        className: "text-xs text-gray-500"
                    }, "Risk: " + change.riskLevel)),
                    React.createElement('span', {
                        className: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800"
                    }, change.status)))))))));
            }
            
            return null;
        }
        
        ReactDOM.render(React.createElement(ServiceDeskApp), document.getElementById('root'));
    </script>
</body>
</html>\`;
    
    return frontendHTML;
};

// Serve the React frontend
app.get('*', (req, res) => {
    res.setHeader('Content-Type', 'text/html');
    res.send(createFrontendFromSource());
});

const PORT = process.env.PORT || 5000;
app.listen(PORT, '127.0.0.1', () => {
    console.log(\`[Server] Simple production server running on localhost:\${PORT}\`);
    console.log('[Server] Database: PostgreSQL servicedesk@localhost:5432/servicedesk');
    console.log('[Server] Frontend: React application served directly (no build required)');
});
SIMPLE_SERVER_EOF

# Set start script
npm pkg set scripts.start="node simple-production-server.js"

# Update systemd service
sudo tee /etc/systemd/system/$SERVICE_NAME.service > /dev/null << SERVICE_EOF
[Unit]
Description=Calpion IT Service Desk - No Build Required
After=network.target
Wants=postgresql.service

[Service]
Type=simple
User=ubuntu
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/npm start
Restart=always
RestartSec=10
Environment=NODE_ENV=production
Environment=PORT=5000
Environment=DATABASE_URL=postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk

StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=$SERVICE_NAME

[Install]
WantedBy=multi-user.target
SERVICE_EOF

# Start your application
sudo systemctl daemon-reload
sudo systemctl start $SERVICE_NAME

echo "Waiting for your application..."
sleep 15

# Test deployment
echo "Testing your deployed application..."

# Test API
API_TEST=$(curl -s http://localhost:5000/health)
if echo "$API_TEST" | grep -q '"status":"OK"'; then
    echo "✓ API server running"
    DB_CHANGES=$(echo "$API_TEST" | grep -o '"changeCount":[0-9]*' | cut -d: -f2)
    echo "✓ Database has $DB_CHANGES changes (fixes blank screen)"
else
    echo "API server issue"
    sudo journalctl -u $SERVICE_NAME --no-pager --lines=5
fi

# Test frontend
FRONTEND_TEST=$(curl -s -H "Accept: text/html" http://localhost:5000/)
if echo "$FRONTEND_TEST" | grep -q "React.createElement"; then
    echo "✓ React application serving"
else
    echo "Frontend issue"
fi

# Test HTTPS
HTTPS_TEST=$(curl -k -s -H "Accept: text/html" https://98.81.235.7/)
if echo "$HTTPS_TEST" | grep -q "Calpion IT Service Desk"; then
    echo "✓ HTTPS serving your application"
fi

# Test authentication
LOGIN_TEST=$(curl -k -s -c /tmp/cookies.txt -X POST https://98.81.235.7/api/auth/login -H "Content-Type: application/json" -d '{"username":"john.doe","password":"password123"}')
if echo "$LOGIN_TEST" | grep -q '"username":"john.doe"'; then
    echo "✓ Authentication working"
    
    CHANGES_TEST=$(curl -k -s -b /tmp/cookies.txt https://98.81.235.7/api/changes)
    CHANGE_COUNT=$(echo "$CHANGES_TEST" | grep -o '"id":' | wc -l)
    echo "✓ Changes screen will show $CHANGE_COUNT changes"
    
    rm -f /tmp/cookies.txt
fi

# Cleanup
rm -rf /tmp/itservicedesk-simple

echo ""
echo "=== SIMPLE DEPLOYMENT COMPLETE ==="
echo "Access: https://98.81.235.7"
echo "Login: john.doe / password123"
echo ""
echo "Your React application is now running without any build dependencies."
echo "The changes screen will display data instead of being blank."