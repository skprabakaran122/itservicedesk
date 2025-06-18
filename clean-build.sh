#!/bin/bash

# Clean build from scratch - Complete IT Service Desk
cd /var/www/itservicedesk

echo "Creating clean build from scratch..."

# Remove everything and start fresh
sudo rm -rf * .* 2>/dev/null || true
pm2 delete all 2>/dev/null || true
sudo pkill -f node 2>/dev/null || true

# Create package.json
cat > package.json << 'EOF'
{
  "name": "calpion-servicedesk",
  "version": "1.0.0",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "express-session": "^1.17.3",
    "pg": "^8.11.3"
  }
}
EOF

# Install dependencies
npm install

# Create database
sudo -u postgres psql << 'EOF'
DROP DATABASE IF EXISTS servicedesk;
CREATE DATABASE servicedesk;
\c servicedesk

CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username TEXT NOT NULL UNIQUE,
    email TEXT NOT NULL UNIQUE,
    password TEXT NOT NULL,
    role VARCHAR(20) NOT NULL,
    name TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    category VARCHAR(50) NOT NULL,
    description TEXT,
    is_active VARCHAR(10) DEFAULT 'true',
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE tickets (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    status VARCHAR(20) NOT NULL,
    priority VARCHAR(20) NOT NULL,
    category VARCHAR(50) NOT NULL,
    product VARCHAR(100),
    requester_email TEXT,
    requester_name TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE changes (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    status VARCHAR(20) NOT NULL,
    priority VARCHAR(20) NOT NULL,
    category VARCHAR(50) NOT NULL,
    risk_level VARCHAR(20) NOT NULL,
    requested_by TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

INSERT INTO users (username, email, password, role, name) VALUES
('admin', 'admin@calpion.com', 'password123', 'admin', 'System Administrator'),
('support', 'support@calpion.com', 'password123', 'technician', 'Support Technician'),
('manager', 'manager@calpion.com', 'password123', 'manager', 'IT Manager'),
('user', 'user@calpion.com', 'password123', 'user', 'End User');

INSERT INTO products (name, category, description) VALUES
('Microsoft Office 365', 'Software', 'Office productivity suite'),
('Windows 10', 'Operating System', 'Desktop operating system'),
('VPN Access', 'Network', 'Remote access solution'),
('Printer Access', 'Hardware', 'Network printer configuration'),
('Email Setup', 'Communication', 'Email account configuration');

INSERT INTO tickets (title, description, status, priority, category, product, requester_email, requester_name) VALUES
('Cannot access email', 'Unable to login to Outlook', 'open', 'medium', 'software', 'Microsoft Office 365', 'john@calpion.com', 'John Smith'),
('Printer not working', 'Printer showing offline status', 'pending', 'low', 'hardware', 'Printer Access', 'jane@calpion.com', 'Jane Doe'),
('VPN connection issues', 'Cannot connect to company VPN', 'in-progress', 'high', 'network', 'VPN Access', 'bob@calpion.com', 'Bob Johnson');

INSERT INTO changes (title, description, status, priority, category, risk_level, requested_by) VALUES
('Update antivirus software', 'Deploy latest antivirus definitions', 'pending', 'medium', 'system', 'low', 'admin'),
('Network firewall update', 'Apply security patches to firewall', 'approved', 'high', 'infrastructure', 'medium', 'manager');
EOF

# Create server.js
cat > server.js << 'EOF'
const express = require('express');
const { Pool } = require('pg');
const session = require('express-session');
const path = require('path');

const app = express();
const PORT = 5000;

// Database connection
const pool = new Pool({
  host: 'localhost',
  database: 'servicedesk',
  user: 'postgres'
});

// Test database connection
pool.connect()
  .then(client => {
    console.log('Database connected successfully');
    client.release();
  })
  .catch(err => {
    console.error('Database connection failed:', err);
  });

// Middleware
app.use(session({
  secret: 'calpion-secret-key',
  resave: false,
  saveUninitialized: false,
  cookie: { secure: false, httpOnly: true, maxAge: 24 * 60 * 60 * 1000 }
}));

app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(express.static(__dirname));

// Auth middleware
const requireAuth = (req, res, next) => {
  if (!req.session.user) {
    return res.status(401).json({ message: 'Not authenticated' });
  }
  next();
};

// Authentication routes
app.post('/api/auth/login', async (req, res) => {
  try {
    const { username, password } = req.body;
    console.log('Login attempt:', username);
    
    const result = await pool.query('SELECT * FROM users WHERE username = $1 AND password = $2', [username, password]);
    
    if (result.rows.length === 0) {
      console.log('Login failed: Invalid credentials');
      return res.status(401).json({ message: 'Invalid credentials' });
    }
    
    const user = result.rows[0];
    req.session.user = {
      id: user.id,
      username: user.username,
      email: user.email,
      role: user.role,
      name: user.name
    };
    
    console.log('Login successful:', user.username);
    res.json({ user: req.session.user });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ message: 'Internal server error' });
  }
});

app.get('/api/auth/me', (req, res) => {
  if (!req.session.user) {
    return res.status(401).json({ message: 'Not authenticated' });
  }
  res.json({ user: req.session.user });
});

app.post('/api/auth/logout', (req, res) => {
  req.session.destroy((err) => {
    if (err) return res.status(500).json({ message: 'Could not log out' });
    res.json({ message: 'Logged out successfully' });
  });
});

// API routes
app.get('/api/users', requireAuth, async (req, res) => {
  try {
    const result = await pool.query('SELECT id, username, email, name, role FROM users ORDER BY id');
    res.json(result.rows);
  } catch (error) {
    console.error('Users error:', error);
    res.status(500).json({ message: 'Internal server error' });
  }
});

app.get('/api/products', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM products WHERE is_active = $1 ORDER BY name', ['true']);
    res.json(result.rows);
  } catch (error) {
    console.error('Products error:', error);
    res.status(500).json({ message: 'Internal server error' });
  }
});

app.get('/api/tickets', requireAuth, async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM tickets ORDER BY id DESC LIMIT 50');
    res.json(result.rows);
  } catch (error) {
    console.error('Tickets error:', error);
    res.status(500).json({ message: 'Internal server error' });
  }
});

app.get('/api/changes', requireAuth, async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM changes ORDER BY id DESC LIMIT 50');
    res.json(result.rows);
  } catch (error) {
    console.error('Changes error:', error);
    res.status(500).json({ message: 'Internal server error' });
  }
});

// Serve React app
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'index.html'));
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Calpion IT Service Desk running on port ${PORT}`);
});
EOF

# Create index.html with complete React application
cat > index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Calpion IT Service Desk</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://unpkg.com/react@18/umd/react.development.js"></script>
    <script src="https://unpkg.com/react-dom@18/umd/react-dom.development.js"></script>
    <script src="https://unpkg.com/@babel/standalone/babel.min.js"></script>
    <style>
        .fade-in { animation: fadeIn 0.5s ease-in; }
        @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
    </style>
</head>
<body class="bg-gray-50">
    <div id="root"></div>
    <script type="text/babel">
        const { useState, useEffect } = React;
        
        function App() {
            const [user, setUser] = useState(null);
            const [loading, setLoading] = useState(true);
            const [activeTab, setActiveTab] = useState('dashboard');
            const [credentials, setCredentials] = useState({ username: '', password: '' });
            const [data, setData] = useState({ tickets: [], changes: [], products: [], users: [] });
            
            useEffect(() => {
                checkAuth();
            }, []);
            
            const checkAuth = async () => {
                try {
                    const response = await fetch('/api/auth/me');
                    if (response.ok) {
                        const result = await response.json();
                        setUser(result.user);
                        await loadData();
                    }
                } catch (err) {
                    console.log('Not authenticated');
                } finally {
                    setLoading(false);
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
                } catch (err) {
                    console.error('Error loading data:', err);
                }
            };
            
            const handleLogin = async (e) => {
                e.preventDefault();
                try {
                    const response = await fetch('/api/auth/login', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify(credentials)
                    });
                    
                    if (response.ok) {
                        const result = await response.json();
                        setUser(result.user);
                        await loadData();
                    } else {
                        alert('Invalid credentials');
                    }
                } catch (err) {
                    alert('Login failed');
                }
            };
            
            const handleLogout = async () => {
                try {
                    await fetch('/api/auth/logout', { method: 'POST' });
                    setUser(null);
                    setData({ tickets: [], changes: [], products: [], users: [] });
                } catch (err) {
                    console.error('Logout error:', err);
                }
            };
            
            if (loading) {
                return (
                    <div className="min-h-screen bg-gray-50 flex items-center justify-center">
                        <div className="text-center">
                            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
                            <p className="text-gray-600">Loading Calpion IT Service Desk...</p>
                        </div>
                    </div>
                );
            }
            
            if (!user) {
                return (
                    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 flex items-center justify-center">
                        <div className="bg-white rounded-lg shadow-xl p-8 w-full max-w-md">
                            <div className="text-center mb-8">
                                <div className="w-24 h-24 bg-blue-600 rounded-full mx-auto mb-4 flex items-center justify-center shadow-lg">
                                    <span className="text-3xl font-bold text-white">C</span>
                                </div>
                                <h1 className="text-2xl font-bold text-gray-900">Calpion IT Service Desk</h1>
                                <p className="text-gray-600 mt-2">Professional IT Support Platform</p>
                            </div>
                            
                            <form onSubmit={handleLogin} className="space-y-4">
                                <div>
                                    <label className="block text-gray-700 text-sm font-medium mb-2">Username</label>
                                    <input
                                        type="text"
                                        value={credentials.username}
                                        onChange={(e) => setCredentials({...credentials, username: e.target.value})}
                                        className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                                        required
                                    />
                                </div>
                                
                                <div>
                                    <label className="block text-gray-700 text-sm font-medium mb-2">Password</label>
                                    <input
                                        type="password"
                                        value={credentials.password}
                                        onChange={(e) => setCredentials({...credentials, password: e.target.value})}
                                        className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                                        required
                                    />
                                </div>
                                
                                <button
                                    type="submit"
                                    className="w-full bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-4 rounded-lg transition-colors duration-200"
                                >
                                    Sign In to Dashboard
                                </button>
                            </form>
                            
                            <div className="mt-6 p-3 bg-gray-50 rounded-lg">
                                <p className="text-xs text-gray-600 text-center">Demo Accounts:</p>
                                <p className="text-xs text-gray-500 text-center">admin/password123 • support/password123</p>
                            </div>
                        </div>
                    </div>
                );
            }
            
            const stats = {
                totalTickets: data.tickets.length,
                openTickets: data.tickets.filter(t => t.status === 'open').length,
                pendingChanges: data.changes.filter(c => c.status === 'pending').length,
                totalProducts: data.products.length
            };
            
            return (
                <div className="min-h-screen bg-gray-50 fade-in">
                    {/* Header */}
                    <div className="bg-white shadow-sm border-b">
                        <div className="max-w-7xl mx-auto px-4 py-4">
                            <div className="flex justify-between items-center">
                                <div className="flex items-center">
                                    <div className="w-10 h-10 bg-blue-600 rounded-lg flex items-center justify-center mr-3 shadow-md">
                                        <span className="text-white font-bold text-lg">C</span>
                                    </div>
                                    <div>
                                        <h1 className="text-xl font-semibold text-gray-900">Calpion IT Service Desk</h1>
                                        <p className="text-sm text-gray-500">Professional Support Platform</p>
                                    </div>
                                </div>
                                <div className="flex items-center space-x-4">
                                    <div className="text-right">
                                        <p className="text-sm font-medium text-gray-900">{user.name}</p>
                                        <p className="text-xs text-gray-500 capitalize">{user.role}</p>
                                    </div>
                                    <button 
                                        onClick={handleLogout} 
                                        className="bg-gray-100 hover:bg-gray-200 text-gray-700 text-sm px-4 py-2 rounded-lg transition-colors"
                                    >
                                        Logout
                                    </button>
                                </div>
                            </div>
                        </div>
                    </div>

                    {/* Navigation */}
                    <div className="bg-white border-b">
                        <div className="max-w-7xl mx-auto px-4">
                            <nav className="flex space-x-8">
                                {[
                                    { id: 'dashboard', label: 'Dashboard', icon: '📊' },
                                    { id: 'tickets', label: 'Tickets', icon: '🎫' },
                                    { id: 'changes', label: 'Changes', icon: '🔄' },
                                    { id: 'products', label: 'Products', icon: '📦' },
                                    { id: 'users', label: 'Users', icon: '👥' }
                                ].map(tab => (
                                    <button
                                        key={tab.id}
                                        onClick={() => setActiveTab(tab.id)}
                                        className={\`py-4 px-1 border-b-2 font-medium text-sm flex items-center space-x-2 \${
                                            activeTab === tab.id
                                                ? 'border-blue-500 text-blue-600'
                                                : 'border-transparent text-gray-500 hover:text-gray-700'
                                        }\`}
                                    >
                                        <span>{tab.icon}</span>
                                        <span>{tab.label}</span>
                                    </button>
                                ))}
                            </nav>
                        </div>
                    </div>

                    {/* Content */}
                    <div className="max-w-7xl mx-auto px-4 py-8">
                        {activeTab === 'dashboard' && (
                            <div className="fade-in">
                                <h2 className="text-2xl font-bold text-gray-900 mb-6">Dashboard Overview</h2>
                                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
                                    <div className="bg-white rounded-lg shadow p-6 border-l-4 border-blue-500">
                                        <div className="flex items-center">
                                            <div className="p-3 bg-blue-100 rounded-lg mr-4">
                                                <span className="text-2xl">🎫</span>
                                            </div>
                                            <div>
                                                <p className="text-sm text-gray-600">Total Tickets</p>
                                                <p className="text-3xl font-bold text-gray-900">{stats.totalTickets}</p>
                                            </div>
                                        </div>
                                    </div>
                                    <div className="bg-white rounded-lg shadow p-6 border-l-4 border-yellow-500">
                                        <div className="flex items-center">
                                            <div className="p-3 bg-yellow-100 rounded-lg mr-4">
                                                <span className="text-2xl">⚠️</span>
                                            </div>
                                            <div>
                                                <p className="text-sm text-gray-600">Open Tickets</p>
                                                <p className="text-3xl font-bold text-gray-900">{stats.openTickets}</p>
                                            </div>
                                        </div>
                                    </div>
                                    <div className="bg-white rounded-lg shadow p-6 border-l-4 border-green-500">
                                        <div className="flex items-center">
                                            <div className="p-3 bg-green-100 rounded-lg mr-4">
                                                <span className="text-2xl">🔄</span>
                                            </div>
                                            <div>
                                                <p className="text-sm text-gray-600">Pending Changes</p>
                                                <p className="text-3xl font-bold text-gray-900">{stats.pendingChanges}</p>
                                            </div>
                                        </div>
                                    </div>
                                    <div className="bg-white rounded-lg shadow p-6 border-l-4 border-purple-500">
                                        <div className="flex items-center">
                                            <div className="p-3 bg-purple-100 rounded-lg mr-4">
                                                <span className="text-2xl">📦</span>
                                            </div>
                                            <div>
                                                <p className="text-sm text-gray-600">Products</p>
                                                <p className="text-3xl font-bold text-gray-900">{stats.totalProducts}</p>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        )}
                        
                        {activeTab === 'tickets' && (
                            <div className="fade-in">
                                <h2 className="text-2xl font-bold text-gray-900 mb-6">Support Tickets</h2>
                                <div className="bg-white rounded-lg shadow overflow-hidden">
                                    <table className="min-w-full">
                                        <thead className="bg-gray-50">
                                            <tr>
                                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Ticket</th>
                                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Title</th>
                                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Priority</th>
                                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Requester</th>
                                            </tr>
                                        </thead>
                                        <tbody className="bg-white divide-y divide-gray-200">
                                            {data.tickets.map(ticket => (
                                                <tr key={ticket.id} className="hover:bg-gray-50">
                                                    <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">#{ticket.id}</td>
                                                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">{ticket.title}</td>
                                                    <td className="px-6 py-4 whitespace-nowrap">
                                                        <span className={\`inline-flex px-2 py-1 text-xs font-semibold rounded-full \${
                                                            ticket.status === 'open' ? 'bg-blue-100 text-blue-800' :
                                                            ticket.status === 'pending' ? 'bg-yellow-100 text-yellow-800' :
                                                            ticket.status === 'in-progress' ? 'bg-orange-100 text-orange-800' :
                                                            'bg-gray-100 text-gray-800'
                                                        }\`}>
                                                            {ticket.status}
                                                        </span>
                                                    </td>
                                                    <td className="px-6 py-4 whitespace-nowrap">
                                                        <span className={\`inline-flex px-2 py-1 text-xs font-semibold rounded-full \${
                                                            ticket.priority === 'high' ? 'bg-red-100 text-red-800' :
                                                            ticket.priority === 'medium' ? 'bg-yellow-100 text-yellow-800' :
                                                            'bg-green-100 text-green-800'
                                                        }\`}>
                                                            {ticket.priority}
                                                        </span>
                                                    </td>
                                                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">{ticket.requester_name || ticket.requester_email}</td>
                                                </tr>
                                            ))}
                                        </tbody>
                                    </table>
                                </div>
                            </div>
                        )}
                        
                        {activeTab === 'changes' && (
                            <div className="fade-in">
                                <h2 className="text-2xl font-bold text-gray-900 mb-6">Change Requests</h2>
                                <div className="bg-white rounded-lg shadow overflow-hidden">
                                    <table className="min-w-full">
                                        <thead className="bg-gray-50">
                                            <tr>
                                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Change</th>
                                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Title</th>
                                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Risk Level</th>
                                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Requested By</th>
                                            </tr>
                                        </thead>
                                        <tbody className="bg-white divide-y divide-gray-200">
                                            {data.changes.map(change => (
                                                <tr key={change.id} className="hover:bg-gray-50">
                                                    <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">#{change.id}</td>
                                                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">{change.title}</td>
                                                    <td className="px-6 py-4 whitespace-nowrap">
                                                        <span className={\`inline-flex px-2 py-1 text-xs font-semibold rounded-full \${
                                                            change.status === 'approved' ? 'bg-green-100 text-green-800' :
                                                            change.status === 'pending' ? 'bg-yellow-100 text-yellow-800' :
                                                            'bg-gray-100 text-gray-800'
                                                        }\`}>
                                                            {change.status}
                                                        </span>
                                                    </td>
                                                    <td className="px-6 py-4 whitespace-nowrap">
                                                        <span className={\`inline-flex px-2 py-1 text-xs font-semibold rounded-full \${
                                                            change.risk_level === 'high' ? 'bg-red-100 text-red-800' :
                                                            change.risk_level === 'medium' ? 'bg-yellow-100 text-yellow-800' :
                                                            'bg-green-100 text-green-800'
                                                        }\`}>
                                                            {change.risk_level}
                                                        </span>
                                                    </td>
                                                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">{change.requested_by}</td>
                                                </tr>
                                            ))}
                                        </tbody>
                                    </table>
                                </div>
                            </div>
                        )}
                        
                        {activeTab === 'products' && (
                            <div className="fade-in">
                                <h2 className="text-2xl font-bold text-gray-900 mb-6">IT Products & Services</h2>
                                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                                    {data.products.map(product => (
                                        <div key={product.id} className="bg-white rounded-lg shadow-md p-6 border border-gray-200">
                                            <div className="flex items-start space-x-3">
                                                <div className="p-2 bg-blue-100 rounded-lg">
                                                    <span className="text-lg">📦</span>
                                                </div>
                                                <div className="flex-1">
                                                    <h3 className="font-semibold text-gray-900 mb-1">{product.name}</h3>
                                                    <p className="text-sm text-blue-600 mb-2">{product.category}</p>
                                                    <p className="text-sm text-gray-600">{product.description}</p>
                                                </div>
                                            </div>
                                        </div>
                                    ))}
                                </div>
                            </div>
                        )}
                        
                        {activeTab === 'users' && (
                            <div className="fade-in">
                                <h2 className="text-2xl font-bold text-gray-900 mb-6">System Users</h2>
                                <div className="bg-white rounded-lg shadow overflow-hidden">
                                    <table className="min-w-full">
                                        <thead className="bg-gray-50">
                                            <tr>
                                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">User</th>
                                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Name</th>
                                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Username</th>
                                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Email</th>
                                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Role</th>
                                            </tr>
                                        </thead>
                                        <tbody className="bg-white divide-y divide-gray-200">
                                            {data.users.map(user => (
                                                <tr key={user.id} className="hover:bg-gray-50">
                                                    <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">#{user.id}</td>
                                                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">{user.name}</td>
                                                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">{user.username}</td>
                                                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">{user.email}</td>
                                                    <td className="px-6 py-4 whitespace-nowrap">
                                                        <span className={\`inline-flex px-2 py-1 text-xs font-semibold rounded-full \${
                                                            user.role === 'admin' ? 'bg-red-100 text-red-800' :
                                                            user.role === 'manager' ? 'bg-blue-100 text-blue-800' :
                                                            user.role === 'technician' ? 'bg-green-100 text-green-800' :
                                                            'bg-gray-100 text-gray-800'
                                                        }\`}>
                                                            {user.role}
                                                        </span>
                                                    </td>
                                                </tr>
                                            ))}
                                        </tbody>
                                    </table>
                                </div>
                            </div>
                        )}
                    </div>
                </div>
            );
        }
        
        ReactDOM.render(<App />, document.getElementById('root'));
    </script>
</body>
</html>
EOF

# Start the application
echo "Starting Calpion IT Service Desk..."
node server.js &
SERVER_PID=$!

# Wait for startup
sleep 5

# Test the application
echo "Testing application..."
HEALTH_CHECK=$(curl -s http://localhost:5000/ | head -1)

if [[ "$HEALTH_CHECK" == *"DOCTYPE"* ]]; then
    echo "✅ Application started successfully"
    
    # Test login
    LOGIN_TEST=$(curl -s -X POST http://localhost:5000/api/auth/login \
        -H "Content-Type: application/json" \
        -d '{"username":"admin","password":"password123"}')
    
    if [[ "$LOGIN_TEST" == *"admin"* ]]; then
        echo "✅ Authentication working"
    else
        echo "⚠️ Authentication may need checking"
    fi
    
    # Configure nginx
    sudo tee /etc/nginx/sites-available/default > /dev/null << 'NGINX_CONFIG'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    location / {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
NGINX_CONFIG
    
    sudo nginx -t && sudo systemctl reload nginx
    
    echo ""
    echo "🎉 CALPION IT SERVICE DESK DEPLOYED SUCCESSFULLY"
    echo "=============================================="
    echo ""
    echo "✅ Clean build from scratch completed"
    echo "✅ Database created with sample data"
    echo "✅ Application running on port 5000"
    echo "✅ Nginx proxy configured"
    echo ""
    echo "🌐 Access your application:"
    echo "   http://98.81.235.7"
    echo ""
    echo "🔐 Login credentials:"
    echo "   admin / password123 (Administrator)"
    echo "   support / password123 (Technician)"
    echo "   manager / password123 (Manager)"
    echo "   user / password123 (End User)"
    echo ""
    echo "📊 Features available:"
    echo "   • Dashboard with statistics"
    echo "   • Ticket management"
    echo "   • Change request tracking"
    echo "   • Product catalog"
    echo "   • User management"
    echo ""
    echo "🔧 Application PID: $SERVER_PID"
    echo "   To stop: kill $SERVER_PID"
    echo ""
    
else
    echo "❌ Application failed to start"
    kill $SERVER_PID 2>/dev/null
    exit 1
fi
EOF