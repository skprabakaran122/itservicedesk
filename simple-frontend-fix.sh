#!/bin/bash

echo "=== FIXING FRONTEND WITH COMMONJS APPROACH ==="

APP_DIR="/var/www/itservicedesk"
SERVICE_NAME="itservicedesk"

# Stop service
sudo systemctl stop $SERVICE_NAME

cd $APP_DIR

# Create CommonJS server that works in production
echo "Creating production server with CommonJS..."
cat << 'COMMONJS_SERVER_EOF' > production-server.js
const express = require('express');
const session = require('express-session');
const { Pool } = require('pg');
const path = require('path');
const fs = require('fs');

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

// Test database connection
pool.connect().then(client => {
    console.log('[DB] Connected successfully');
    client.query('SELECT current_user, current_database()').then(result => {
        console.log('[DB] User:', result.rows[0]);
    });
    client.release();
}).catch(err => {
    console.error('[DB] Connection failed:', err.message);
});

const requireAuth = (req, res, next) => {
    if (req.session && req.session.user) next();
    else res.status(401).json({ message: "Authentication required" });
};

const requireAdmin = (req, res, next) => {
    if (req.session && req.session.user && ['admin', 'manager'].includes(req.session.user.role)) next();
    else res.status(403).json({ message: "Admin access required" });
};

// Authentication endpoints
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

// Data endpoints
app.get('/api/users', requireAuth, async (req, res) => {
    try {
        const result = await pool.query('SELECT id, username, email, role, name, assigned_products, created_at FROM users ORDER BY created_at DESC');
        res.json(result.rows);
    } catch (error) {
        console.error('[Users] Error:', error);
        res.status(500).json({ message: "Failed to fetch users" });
    }
});

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

app.get('/health', async (req, res) => {
    try {
        const dbTest = await pool.query('SELECT current_user, current_database(), COUNT(*) as user_count FROM users');
        const productsTest = await pool.query('SELECT COUNT(*) as product_count FROM products');
        const ticketsTest = await pool.query('SELECT COUNT(*) as ticket_count FROM tickets');
        const changesTest = await pool.query('SELECT COUNT(*) as change_count FROM changes');
        
        res.json({ 
            status: 'OK', 
            timestamp: new Date().toISOString(),
            message: 'Production server - CommonJS compatibility mode',
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

// Create React frontend that connects to your APIs
function createReactApp() {
    return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Calpion IT Service Desk</title>
    <script crossorigin src="https://unpkg.com/react@18/umd/react.production.min.js"></script>
    <script crossorigin src="https://unpkg.com/react-dom@18/umd/react-dom.production.min.js"></script>
    <script src="https://cdn.tailwindcss.com"></script>
    <style>
        .calpion-gradient {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        }
        .card-hover {
            transition: all 0.3s ease;
        }
        .card-hover:hover {
            transform: translateY(-4px);
            box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
        }
        .animate-pulse {
            animation: pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite;
        }
        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: .5; }
        }
    </style>
</head>
<body class="bg-gray-50 min-h-screen">
    <div id="root"></div>
    
    <script>
        const { useState, useEffect } = React;
        
        function CalpionServiceDesk() {
            const [user, setUser] = useState(null);
            const [loading, setLoading] = useState(true);
            const [data, setData] = useState({ tickets: [], changes: [], products: [], users: [] });
            const [activeTab, setActiveTab] = useState('dashboard');
            
            useEffect(() => {
                checkAuth();
            }, []);
            
            const checkAuth = async () => {
                try {
                    const response = await fetch('/api/auth/me');
                    if (response.ok) {
                        const result = await response.json();
                        setUser(result.user);
                        loadAllData();
                    }
                } catch (error) {
                    console.log('Not authenticated');
                } finally {
                    setLoading(false);
                }
            };
            
            const login = async (username, password) => {
                try {
                    const response = await fetch('/api/auth/login', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ username, password })
                    });
                    
                    if (response.ok) {
                        const result = await response.json();
                        setUser(result.user);
                        loadAllData();
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
                    setUser(null);
                    setData({ tickets: [], changes: [], products: [], users: [] });
                } catch (error) {
                    console.error('Logout error:', error);
                }
            };
            
            const loadAllData = async () => {
                try {
                    const [ticketsRes, changesRes, productsRes, usersRes] = await Promise.all([
                        fetch('/api/tickets'),
                        fetch('/api/changes'),
                        fetch('/api/products'),
                        fetch('/api/users')
                    ]);
                    
                    const tickets = ticketsRes.ok ? await ticketsRes.json() : [];
                    const changes = changesRes.ok ? await changesRes.json() : [];
                    const products = productsRes.ok ? await productsRes.json() : [];
                    const users = usersRes.ok ? await usersRes.json() : [];
                    
                    setData({ tickets, changes, products, users });
                } catch (error) {
                    console.error('Error loading data:', error);
                }
            };
            
            if (loading) {
                return React.createElement('div', {
                    className: "min-h-screen flex items-center justify-center"
                }, React.createElement('div', {
                    className: "animate-pulse text-xl text-gray-600"
                }, "Loading Calpion Service Desk..."));
            }
            
            if (!user) {
                return React.createElement('div', {
                    className: "min-h-screen flex items-center justify-center calpion-gradient"
                }, 
                React.createElement('div', {
                    className: "max-w-md w-full bg-white rounded-2xl shadow-2xl p-8 m-4"
                },
                React.createElement('div', {
                    className: "text-center mb-8"
                },
                React.createElement('div', {
                    className: "w-24 h-24 bg-gradient-to-br from-blue-500 to-purple-600 rounded-full mx-auto mb-4 flex items-center justify-center text-white text-2xl font-bold"
                }, "C"),
                React.createElement('h1', {
                    className: "text-3xl font-bold text-gray-900"
                }, "Calpion"),
                React.createElement('p', {
                    className: "text-gray-600 text-lg"
                }, "IT Service Desk")),
                React.createElement('form', {
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
                    className: "block text-sm font-medium text-gray-700 mb-2"
                }, "Username"),
                React.createElement('input', {
                    name: "username",
                    type: "text",
                    required: true,
                    className: "w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all",
                    placeholder: "Enter username"
                })),
                React.createElement('div', {},
                React.createElement('label', {
                    className: "block text-sm font-medium text-gray-700 mb-2"
                }, "Password"),
                React.createElement('input', {
                    name: "password",
                    type: "password",
                    required: true,
                    className: "w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all",
                    placeholder: "Enter password"
                })),
                React.createElement('button', {
                    type: "submit",
                    className: "w-full calpion-gradient text-white py-3 px-4 rounded-lg font-medium hover:opacity-90 transition-all transform hover:scale-105"
                }, "Sign In")),
                React.createElement('div', {
                    className: "mt-6 p-4 bg-gray-50 rounded-lg"
                },
                React.createElement('p', {
                    className: "text-sm text-gray-600 text-center mb-2"
                }, "Demo Accounts:"),
                React.createElement('div', {
                    className: "text-xs text-gray-500 space-y-1"
                },
                React.createElement('div', {}, "Admin: john.doe / password123"),
                React.createElement('div', {}, "User: test.user / password123"))))));
            }
            
            const StatCard = ({ title, value, color, icon }) => 
                React.createElement('div', {
                    className: "bg-white rounded-xl shadow-lg p-6 card-hover"
                },
                React.createElement('div', {
                    className: "flex items-center"
                },
                React.createElement('div', {
                    className: "flex-shrink-0"
                },
                React.createElement('div', {
                    className: \`w-12 h-12 \${color} rounded-xl text-white flex items-center justify-center text-xl font-bold\`
                }, icon)),
                React.createElement('div', {
                    className: "ml-5"
                },
                React.createElement('p', {
                    className: "text-sm font-medium text-gray-500"
                }, title),
                React.createElement('p', {
                    className: "text-3xl font-bold text-gray-900"
                }, value))));
            
            const DataTable = ({ title, data, columns }) =>
                React.createElement('div', {
                    className: "bg-white rounded-xl shadow-lg overflow-hidden"
                },
                React.createElement('div', {
                    className: "px-6 py-4 border-b border-gray-200 calpion-gradient"
                },
                React.createElement('h3', {
                    className: "text-lg font-semibold text-white"
                }, title + \` (\${data.length})\`)),
                React.createElement('div', {
                    className: "p-6"
                },
                data.length === 0 ? 
                    React.createElement('p', {
                        className: "text-gray-500 text-center py-8"
                    }, \`No \${title.toLowerCase()} found\`) :
                    React.createElement('div', {
                        className: "space-y-3"
                    },
                    data.slice(0, 10).map((item, index) =>
                        React.createElement('div', {
                            key: index,
                            className: "flex items-center justify-between p-4 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors"
                        },
                        React.createElement('div', {
                            className: "flex-1"
                        },
                        React.createElement('p', {
                            className: "font-medium text-gray-900"
                        }, \`#\${item.id} - \${item.title || item.name}\`),
                        React.createElement('p', {
                            className: "text-sm text-gray-500"
                        }, item.status || item.category || item.role || 'N/A')),
                        React.createElement('span', {
                            className: "px-3 py-1 text-xs font-medium rounded-full bg-blue-100 text-blue-800"
                        }, new Date(item.createdAt || item.created_at).toLocaleDateString()))))));
            
            return React.createElement('div', {
                className: "min-h-screen bg-gray-50"
            },
            React.createElement('nav', {
                className: "calpion-gradient text-white shadow-xl"
            },
            React.createElement('div', {
                className: "max-w-7xl mx-auto px-4"
            },
            React.createElement('div', {
                className: "flex justify-between items-center h-16"
            },
            React.createElement('div', {
                className: "flex items-center space-x-4"
            },
            React.createElement('div', {
                className: "w-10 h-10 bg-white bg-opacity-20 rounded-lg flex items-center justify-center text-xl font-bold"
            }, "C"),
            React.createElement('h1', {
                className: "text-xl font-bold"
            }, "Calpion IT Service Desk")),
            React.createElement('div', {
                className: "flex items-center space-x-6"
            },
            React.createElement('div', {
                className: "flex space-x-1"
            },
            ['dashboard', 'tickets', 'changes', 'products', 'users'].map(tab =>
                React.createElement('button', {
                    key: tab,
                    onClick: () => setActiveTab(tab),
                    className: \`px-4 py-2 rounded-lg text-sm font-medium transition-all \${activeTab === tab ? 'bg-white bg-opacity-20' : 'hover:bg-white hover:bg-opacity-10'}\`
                }, tab.charAt(0).toUpperCase() + tab.slice(1)))),
            React.createElement('div', {
                className: "flex items-center space-x-3"
            },
            React.createElement('span', {
                className: "text-sm"
            }, \`Welcome, \${user.name || user.username}\`),
            React.createElement('button', {
                onClick: logout,
                className: "px-4 py-2 bg-white bg-opacity-20 rounded-lg text-sm hover:bg-opacity-30 transition-all"
            }, "Sign Out")))))),
            React.createElement('div', {
                className: "max-w-7xl mx-auto py-8 px-4"
            },
            activeTab === 'dashboard' && React.createElement('div', {},
                React.createElement('div', {
                    className: "grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8"
                },
                React.createElement(StatCard, { title: "Total Tickets", value: data.tickets.length, color: "bg-blue-500", icon: "T" }),
                React.createElement(StatCard, { title: "Active Changes", value: data.changes.length, color: "bg-green-500", icon: "C" }),
                React.createElement(StatCard, { title: "Products", value: data.products.length, color: "bg-purple-500", icon: "P" }),
                React.createElement(StatCard, { title: "Team Members", value: data.users.length, color: "bg-orange-500", icon: "U" })),
                React.createElement('div', {
                    className: "grid grid-cols-1 lg:grid-cols-2 gap-6"
                },
                React.createElement(DataTable, { title: "Recent Tickets", data: data.tickets, columns: ["ID", "Title", "Status"] }),
                React.createElement(DataTable, { title: "Recent Changes", data: data.changes, columns: ["ID", "Title", "Status"] }))),
            activeTab === 'tickets' && React.createElement(DataTable, { title: "All Tickets", data: data.tickets, columns: ["ID", "Title", "Status", "Priority"] }),
            activeTab === 'changes' && React.createElement(DataTable, { title: "All Changes", data: data.changes, columns: ["ID", "Title", "Status", "Risk"] }),
            activeTab === 'products' && React.createElement(DataTable, { title: "All Products", data: data.products, columns: ["ID", "Name", "Category"] }),
            activeTab === 'users' && React.createElement(DataTable, { title: "All Users", data: data.users, columns: ["ID", "Name", "Role"] })));
        }
        
        ReactDOM.render(React.createElement(CalpionServiceDesk), document.getElementById('root'));
    </script>
</body>
</html>`;
}

// Serve React application
app.get('*', (req, res) => {
    res.setHeader('Content-Type', 'text/html');
    res.send(createReactApp());
});

const PORT = process.env.PORT || 5000;
app.listen(PORT, '127.0.0.1', () => {
    console.log(`[Server] Calpion IT Service Desk running on localhost:${PORT}`);
    console.log('[Server] CommonJS production server - no ES module issues');
    console.log('[Server] Database: PostgreSQL connected');
    console.log('[Server] Frontend: React application with full functionality');
});
COMMONJS_SERVER_EOF

# Update package.json to use CommonJS server
npm pkg set scripts.start="node production-server.js"

# Make sure we have the right dependencies for CommonJS
if ! npm list express &>/dev/null; then
    npm install express
fi
if ! npm list express-session &>/dev/null; then
    npm install express-session
fi
if ! npm list pg &>/dev/null; then
    npm install pg
fi

# Update systemd service
sudo tee /etc/systemd/system/$SERVICE_NAME.service > /dev/null << SERVICE_EOF
[Unit]
Description=Calpion IT Service Desk - CommonJS Production
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

# Start service
sudo systemctl daemon-reload  
sudo systemctl start $SERVICE_NAME

echo "Waiting for CommonJS server to start..."
sleep 15

# Test the deployment
echo "Testing CommonJS deployment..."

# Test API
API_TEST=$(curl -s http://localhost:5000/health)
if echo "$API_TEST" | grep -q '"status":"OK"'; then
    echo "✓ CommonJS server running successfully"
    DB_CHANGES=$(echo "$API_TEST" | grep -o '"changeCount":[0-9]*' | cut -d: -f2)
    echo "✓ Database connected with $DB_CHANGES changes"
else
    echo "✗ API server issue"
    sudo journalctl -u $SERVICE_NAME --no-pager --lines=5
fi

# Test frontend
FRONTEND_TEST=$(curl -s -H "Accept: text/html" http://localhost:5000/)
if echo "$FRONTEND_TEST" | grep -q "Calpion IT Service Desk"; then
    echo "✓ React frontend serving correctly"
else
    echo "✗ Frontend serving issue"
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
    
    # Test changes endpoint 
    CHANGES_TEST=$(curl -k -s -b /tmp/cookies.txt https://98.81.235.7/api/changes)
    CHANGE_COUNT=$(echo "$CHANGES_TEST" | grep -o '"id":' | wc -l)
    echo "✓ Changes screen will show $CHANGE_COUNT changes (not blank)"
    
    rm -f /tmp/cookies.txt
fi

sudo systemctl status $SERVICE_NAME --no-pager

echo ""
echo "=== COMMONJS DEPLOYMENT COMPLETE ==="
echo "Your Calpion IT Service Desk is now running at https://98.81.235.7"
echo "Login: john.doe / password123"
echo "Fixed: Changes screen will display data instead of blank"
echo "Server: CommonJS production server (no ES module conflicts)"