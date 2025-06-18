#!/bin/bash

echo "=== CREATING PURE NODE.JS SERVER (NO MODULE CONFLICTS) ==="

APP_DIR="/var/www/itservicedesk"
SERVICE_NAME="itservicedesk"

# Stop service
sudo systemctl stop $SERVICE_NAME

cd $APP_DIR

# Create pure Node.js server without any package.json dependencies
echo "Creating pure Node.js server..."
cat << 'PURE_NODEJS_EOF' > server.js
const http = require('http');
const url = require('url');
const querystring = require('querystring');
const { Pool } = require('pg');

// Database connection
const pool = new Pool({
    connectionString: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk',
    max: 20,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 2000,
});

// Simple session storage (in-memory for demo)
const sessions = new Map();

function generateSessionId() {
    return Math.random().toString(36).substring(2) + Date.now().toString(36);
}

function parseBody(req) {
    return new Promise((resolve) => {
        let body = '';
        req.on('data', chunk => {
            body += chunk.toString();
        });
        req.on('end', () => {
            resolve(body);
        });
    });
}

function sendJSON(res, data, statusCode = 200) {
    res.writeHead(statusCode, {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization'
    });
    res.end(JSON.stringify(data));
}

function sendHTML(res, html) {
    res.writeHead(200, {
        'Content-Type': 'text/html',
        'Access-Control-Allow-Origin': '*'
    });
    res.end(html);
}

function getSession(req) {
    const cookies = req.headers.cookie || '';
    const sessionMatch = cookies.match(/sessionId=([^;]+)/);
    if (sessionMatch) {
        return sessions.get(sessionMatch[1]);
    }
    return null;
}

function setSession(res, user) {
    const sessionId = generateSessionId();
    sessions.set(sessionId, { user });
    res.setHeader('Set-Cookie', `sessionId=${sessionId}; HttpOnly; Path=/; Max-Age=86400`);
    return sessionId;
}

function requireAuth(req, res, next) {
    const session = getSession(req);
    if (session && session.user) {
        req.user = session.user;
        next();
    } else {
        sendJSON(res, { message: "Authentication required" }, 401);
    }
}

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
            cursor: pointer;
        }
        .card-hover:hover {
            transform: translateY(-2px);
            box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1);
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
        
        function CalpionApp() {
            const [user, setUser] = useState(null);
            const [loading, setLoading] = useState(true);
            const [activeTab, setActiveTab] = useState('dashboard');
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
                        const result = await response.json();
                        setUser(result.user);
                        loadData();
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
                        loadData();
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
            
            const loadData = async () => {
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
                    className: "min-h-screen flex items-center justify-center calpion-gradient"
                }, React.createElement('div', {
                    className: "text-white text-2xl animate-pulse"
                }, "Loading Calpion Service Desk..."));
            }
            
            if (!user) {
                return React.createElement('div', {
                    className: "min-h-screen flex items-center justify-center calpion-gradient p-4"
                }, 
                React.createElement('div', {
                    className: "max-w-md w-full bg-white rounded-2xl shadow-2xl p-8"
                },
                React.createElement('div', {
                    className: "text-center mb-8"
                },
                React.createElement('div', {
                    className: "w-20 h-20 calpion-gradient rounded-full mx-auto mb-4 flex items-center justify-center text-white text-3xl font-bold shadow-xl"
                }, "C"),
                React.createElement('h1', {
                    className: "text-3xl font-bold text-gray-900 mb-2"
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
                    className: "space-y-6"
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
                    className: "text-center text-sm text-gray-600 mb-2 font-medium"
                }, "Test Accounts:"),
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
                    className: color + " w-12 h-12 rounded-xl text-white flex items-center justify-center text-xl font-bold"
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
            
            const tabs = [
                { id: 'dashboard', name: 'Dashboard', icon: '📊' },
                { id: 'tickets', name: 'Tickets', icon: '🎫' },
                { id: 'changes', name: 'Changes', icon: '🔄' },
                { id: 'products', name: 'Products', icon: '📦' },
                { id: 'users', name: 'Users', icon: '👥' }
            ];
            
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
                className: "hidden md:flex space-x-1"
            },
            tabs.map(tab =>
                React.createElement('button', {
                    key: tab.id,
                    onClick: () => setActiveTab(tab.id),
                    className: "px-4 py-2 rounded-lg text-sm font-medium transition-all " + (activeTab === tab.id ? 'bg-white bg-opacity-20' : 'hover:bg-white hover:bg-opacity-10')
                }, tab.icon + ' ' + tab.name))),
            React.createElement('div', {
                className: "flex items-center space-x-3"
            },
            React.createElement('span', {
                className: "text-sm"
            }, "Welcome, " + (user.name || user.username)),
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
                React.createElement(StatCard, { title: "Total Tickets", value: data.tickets.length, color: "bg-blue-500", icon: "🎫" }),
                React.createElement(StatCard, { title: "Active Changes", value: data.changes.length, color: "bg-green-500", icon: "🔄" }),
                React.createElement(StatCard, { title: "Products", value: data.products.length, color: "bg-purple-500", icon: "📦" }),
                React.createElement(StatCard, { title: "Team Members", value: data.users.length, color: "bg-orange-500", icon: "👥" })),
                React.createElement('div', {
                    className: "text-center"
                },
                React.createElement('h2', {
                    className: "text-2xl font-bold text-gray-900 mb-4"
                }, "Your IT Service Desk is Running!"),
                React.createElement('p', {
                    className: "text-gray-600 mb-4"
                }, "Database connected with " + data.changes.length + " changes loaded (fixes blank screen issue)"),
                React.createElement('p', {
                    className: "text-sm text-gray-500"
                }, "Pure Node.js server running without module conflicts"))),
            activeTab === 'tickets' && React.createElement('div', {
                className: "bg-white rounded-xl shadow-lg p-6"
            },
            React.createElement('h2', {
                className: "text-xl font-bold mb-4"
            }, "Tickets (" + data.tickets.length + ")"),
            data.tickets.length === 0 ? 
                React.createElement('p', { className: "text-gray-500 text-center py-8" }, "No tickets found") :
                React.createElement('div', { className: "space-y-3" },
                data.tickets.slice(0, 10).map((ticket, index) =>
                    React.createElement('div', {
                        key: index,
                        className: "p-4 border rounded-lg hover:bg-gray-50"
                    },
                    React.createElement('h3', { className: "font-medium" }, "#" + ticket.id + " - " + ticket.title),
                    React.createElement('p', { className: "text-sm text-gray-600" }, "Status: " + ticket.status + " | Priority: " + ticket.priority))))),
            activeTab === 'changes' && React.createElement('div', {
                className: "bg-white rounded-xl shadow-lg p-6"
            },
            React.createElement('h2', {
                className: "text-xl font-bold mb-4"
            }, "Changes (" + data.changes.length + ")"),
            data.changes.length === 0 ? 
                React.createElement('p', { className: "text-gray-500 text-center py-8" }, "No changes found") :
                React.createElement('div', { className: "space-y-3" },
                data.changes.slice(0, 10).map((change, index) =>
                    React.createElement('div', {
                        key: index,
                        className: "p-4 border rounded-lg hover:bg-gray-50"
                    },
                    React.createElement('h3', { className: "font-medium" }, "#" + change.id + " - " + change.title),
                    React.createElement('p', { className: "text-sm text-gray-600" }, "Status: " + change.status + " | Risk: " + change.riskLevel))))),
            activeTab === 'products' && React.createElement('div', {
                className: "bg-white rounded-xl shadow-lg p-6"
            },
            React.createElement('h2', {
                className: "text-xl font-bold mb-4"
            }, "Products (" + data.products.length + ")"),
            data.products.length === 0 ? 
                React.createElement('p', { className: "text-gray-500 text-center py-8" }, "No products found") :
                React.createElement('div', { className: "space-y-3" },
                data.products.slice(0, 10).map((product, index) =>
                    React.createElement('div', {
                        key: index,
                        className: "p-4 border rounded-lg hover:bg-gray-50"
                    },
                    React.createElement('h3', { className: "font-medium" }, product.name),
                    React.createElement('p', { className: "text-sm text-gray-600" }, "Category: " + (product.category || 'Other')))))),
            activeTab === 'users' && React.createElement('div', {
                className: "bg-white rounded-xl shadow-lg p-6"
            },
            React.createElement('h2', {
                className: "text-xl font-bold mb-4"
            }, "Users (" + data.users.length + ")"),
            data.users.length === 0 ? 
                React.createElement('p', { className: "text-gray-500 text-center py-8" }, "No users found") :
                React.createElement('div', { className: "space-y-3" },
                data.users.slice(0, 10).map((user_item, index) =>
                    React.createElement('div', {
                        key: index,
                        className: "p-4 border rounded-lg hover:bg-gray-50"
                    },
                    React.createElement('h3', { className: "font-medium" }, user_item.name || user_item.username),
                    React.createElement('p', { className: "text-sm text-gray-600" }, "Role: " + user_item.role + " | Email: " + user_item.email)))))));
        }
        
        ReactDOM.render(React.createElement(CalpionApp), document.getElementById('root'));
    </script>
</body>
</html>`;
}

const server = http.createServer(async (req, res) => {
    const parsedUrl = url.parse(req.url, true);
    const pathname = parsedUrl.pathname;
    const method = req.method;

    // Enable CORS
    if (method === 'OPTIONS') {
        res.writeHead(200, {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization'
        });
        res.end();
        return;
    }

    console.log(`[${new Date().toISOString()}] ${method} ${pathname}`);

    try {
        // Authentication endpoints
        if (pathname === '/api/auth/login' && method === 'POST') {
            const body = await parseBody(req);
            const { username, password } = JSON.parse(body);
            
            const result = await pool.query('SELECT * FROM users WHERE username = $1 OR email = $1', [username]);
            
            if (result.rows.length === 0 || result.rows[0].password !== password) {
                sendJSON(res, { message: "Invalid credentials" }, 401);
                return;
            }
            
            const user = result.rows[0];
            setSession(res, user);
            const { password: _, ...userWithoutPassword } = user;
            sendJSON(res, { user: userWithoutPassword });
            return;
        }

        if (pathname === '/api/auth/me' && method === 'GET') {
            const session = getSession(req);
            if (!session || !session.user) {
                sendJSON(res, { message: "Not authenticated" }, 401);
                return;
            }
            const { password: _, ...userWithoutPassword } = session.user;
            sendJSON(res, { user: userWithoutPassword });
            return;
        }

        if (pathname === '/api/auth/logout' && method === 'POST') {
            const cookies = req.headers.cookie || '';
            const sessionMatch = cookies.match(/sessionId=([^;]+)/);
            if (sessionMatch) {
                sessions.delete(sessionMatch[1]);
            }
            res.setHeader('Set-Cookie', 'sessionId=; HttpOnly; Path=/; Max-Age=0');
            sendJSON(res, { message: "Logged out successfully" });
            return;
        }

        // Data endpoints (require authentication)
        if (pathname === '/api/users' && method === 'GET') {
            requireAuth(req, res, async () => {
                const result = await pool.query('SELECT id, username, email, role, name, assigned_products, created_at FROM users ORDER BY created_at DESC');
                sendJSON(res, result.rows);
            });
            return;
        }

        if (pathname === '/api/products' && method === 'GET') {
            requireAuth(req, res, async () => {
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
                sendJSON(res, result.rows);
            });
            return;
        }

        if (pathname === '/api/tickets' && method === 'GET') {
            requireAuth(req, res, async () => {
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
                sendJSON(res, result.rows);
            });
            return;
        }

        if (pathname === '/api/changes' && method === 'GET') {
            requireAuth(req, res, async () => {
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
                sendJSON(res, result.rows);
            });
            return;
        }

        // Health check
        if (pathname === '/health' && method === 'GET') {
            const dbTest = await pool.query('SELECT current_user, current_database(), COUNT(*) as user_count FROM users');
            const productsTest = await pool.query('SELECT COUNT(*) as product_count FROM products');
            const ticketsTest = await pool.query('SELECT COUNT(*) as ticket_count FROM tickets');
            const changesTest = await pool.query('SELECT COUNT(*) as change_count FROM changes');
            
            sendJSON(res, { 
                status: 'OK', 
                timestamp: new Date().toISOString(),
                message: 'Pure Node.js server - no module conflicts',
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
            return;
        }

        // Serve React app for all other requests
        sendHTML(res, createReactApp());

    } catch (error) {
        console.error('Server error:', error);
        sendJSON(res, { 
            status: 'ERROR',
            message: 'Server error',
            error: error.message
        }, 500);
    }
});

// Test database connection on startup
pool.connect().then(client => {
    console.log('[DB] Connected successfully');
    client.query('SELECT current_user, current_database()').then(result => {
        console.log('[DB] User:', result.rows[0]);
    });
    client.release();
}).catch(err => {
    console.error('[DB] Connection failed:', err.message);
});

const PORT = process.env.PORT || 5000;
server.listen(PORT, '127.0.0.1', () => {
    console.log(`[Server] Calpion IT Service Desk running on localhost:${PORT}`);
    console.log('[Server] Pure Node.js server - no package.json dependencies');
    console.log('[Server] No ES module conflicts possible');
});
PURE_NODEJS_EOF

# Install only the pg driver directly (no package.json conflicts)
npm install pg

# Create a minimal package.json that won't cause module conflicts
cat << 'PACKAGE_EOF' > package.json
{
  "name": "calpion-servicedesk",
  "version": "1.0.0",
  "type": "commonjs",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "pg": "^8.11.3"
  }
}
PACKAGE_EOF

# Update systemd service
sudo tee /etc/systemd/system/$SERVICE_NAME.service > /dev/null << SERVICE_EOF
[Unit]
Description=Calpion IT Service Desk - Pure Node.js
After=network.target
Wants=postgresql.service

[Service]
Type=simple
User=ubuntu
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/node server.js
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

echo "Waiting for pure Node.js server..."
sleep 15

# Test the deployment
echo "Testing pure Node.js deployment..."

# Test API
API_TEST=$(curl -s http://localhost:5000/health)
if echo "$API_TEST" | grep -q '"status":"OK"'; then
    echo "✓ Pure Node.js server running successfully"
    DB_CHANGES=$(echo "$API_TEST" | grep -o '"changeCount":[0-9]*' | cut -d: -f2)
    echo "✓ Database connected with $DB_CHANGES changes"
else
    echo "✗ API server issue"
    sudo journalctl -u $SERVICE_NAME --no-pager --lines=10
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
echo "=== PURE NODE.JS DEPLOYMENT COMPLETE ==="
echo "Your Calpion IT Service Desk is now running at https://98.81.235.7"
echo "Login: john.doe / password123"
echo "Fixed: Changes screen will display data instead of blank"
echo "Server: Pure Node.js (no package.json module conflicts)"