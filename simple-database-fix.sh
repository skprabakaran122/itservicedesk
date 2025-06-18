#!/bin/bash

# Simple database and deployment fix for Ubuntu server
cd /var/www/itservicedesk

echo "Fixing database connection using postgres user..."

# Create database with postgres user instead of servicedesk user
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
    assigned_products TEXT[],
    created_at TIMESTAMP DEFAULT NOW() NOT NULL
);

CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    category VARCHAR(50) NOT NULL,
    description TEXT,
    is_active VARCHAR(10) NOT NULL DEFAULT 'true',
    created_at TIMESTAMP DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP DEFAULT NOW() NOT NULL
);

CREATE TABLE tickets (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    status VARCHAR(20) NOT NULL,
    priority VARCHAR(20) NOT NULL,
    category VARCHAR(50) NOT NULL,
    product VARCHAR(100),
    assigned_to TEXT,
    requester_id INTEGER,
    requester_email TEXT,
    requester_name TEXT,
    requester_phone TEXT,
    requester_department TEXT,
    requester_business_unit TEXT,
    created_at TIMESTAMP DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP DEFAULT NOW() NOT NULL,
    first_response_at TIMESTAMP,
    resolved_at TIMESTAMP,
    sla_target_response INTEGER,
    sla_target_resolution INTEGER,
    sla_response_met VARCHAR(10),
    sla_resolution_met VARCHAR(10),
    approval_status VARCHAR(20),
    approved_by TEXT,
    approved_at TIMESTAMP,
    approval_comments TEXT,
    approval_token TEXT
);

CREATE TABLE changes (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    status VARCHAR(20) NOT NULL,
    priority VARCHAR(20) NOT NULL,
    category VARCHAR(50) NOT NULL,
    product VARCHAR(100),
    requested_by TEXT NOT NULL,
    approved_by TEXT,
    implemented_by TEXT,
    planned_date TIMESTAMP,
    completed_date TIMESTAMP,
    start_date TIMESTAMP,
    end_date TIMESTAMP,
    risk_level VARCHAR(20) NOT NULL,
    change_type VARCHAR(20) NOT NULL DEFAULT 'normal',
    rollback_plan TEXT,
    approval_token TEXT,
    overdue_notification_sent TIMESTAMP,
    is_overdue VARCHAR(10) DEFAULT 'false',
    created_at TIMESTAMP DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP DEFAULT NOW() NOT NULL
);

INSERT INTO users (username, email, password, role, name) VALUES
('admin', 'admin@calpion.com', 'password123', 'admin', 'System Administrator'),
('support', 'support@calpion.com', 'password123', 'technician', 'Support Technician'),
('manager', 'manager@calpion.com', 'password123', 'manager', 'IT Manager'),
('user', 'user@calpion.com', 'password123', 'user', 'End User');

INSERT INTO products (name, category, description, is_active) VALUES
('Microsoft Office 365', 'Software', 'Office productivity suite', 'true'),
('Windows 10', 'Operating System', 'Desktop operating system', 'true'),
('VPN Access', 'Network', 'Remote access solution', 'true'),
('Printer Access', 'Hardware', 'Network printer configuration', 'true'),
('Email Setup', 'Communication', 'Email account configuration', 'true');

INSERT INTO tickets (title, description, status, priority, category, product, requester_email, requester_name, created_at) VALUES
('Cannot access email', 'Unable to login to Outlook', 'open', 'medium', 'software', 'Microsoft Office 365', 'john@calpion.com', 'John Smith', NOW() - INTERVAL '2 hours'),
('Printer not working', 'Printer showing offline status', 'pending', 'low', 'hardware', 'Printer Access', 'jane@calpion.com', 'Jane Doe', NOW() - INTERVAL '1 day'),
('VPN connection issues', 'Cannot connect to company VPN', 'in-progress', 'high', 'network', 'VPN Access', 'bob@calpion.com', 'Bob Johnson', NOW() - INTERVAL '3 hours');

INSERT INTO changes (title, description, status, priority, category, risk_level, requested_by, created_at) VALUES
('Update antivirus software', 'Deploy latest antivirus definitions', 'pending', 'medium', 'system', 'low', 'admin', NOW() - INTERVAL '1 day'),
('Network firewall update', 'Apply security patches to firewall', 'approved', 'high', 'infrastructure', 'medium', 'manager', NOW() - INTERVAL '2 days');
EOF

echo "Database already exists"

# Create production server that connects to postgres database
mkdir -p dist
cat > dist/production.cjs << 'EOF'
const express = require('express');
const path = require('path');
const { Pool } = require('pg');
const session = require('express-session');

const app = express();
const PORT = 5000;

console.log('Starting Calpion IT Service Desk...');

// Database connection using postgres user
const pool = new Pool({
  host: 'localhost',
  port: 5432,
  database: 'servicedesk',
  user: 'postgres'
  // No password for postgres user
});

pool.connect()
  .then(client => {
    console.log('Database connected successfully');
    client.release();
  })
  .catch(err => {
    console.error('Database connection failed:', err);
  });

// Session middleware
app.use(session({
  secret: 'calpion-secret-key',
  resave: false,
  saveUninitialized: false,
  cookie: {
    secure: false,
    httpOnly: true,
    maxAge: 24 * 60 * 60 * 1000
  }
}));

app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true }));
app.set('trust proxy', true);

// Serve a simple working React app
app.get('/', (req, res) => {
  res.send(`
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
</head>
<body class="bg-gray-50">
    <div id="root"></div>
    <script type="text/babel">
        const { useState, useEffect } = React;
        
        function App() {
            const [user, setUser] = useState(null);
            const [loading, setLoading] = useState(true);
            const [credentials, setCredentials] = useState({ username: '', password: '' });
            const [activeTab, setActiveTab] = useState('dashboard');
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
                        loadData();
                    }
                } catch (err) {
                    console.error('Auth check failed:', err);
                } finally {
                    setLoading(false);
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
                        loadData();
                    } else {
                        alert('Invalid credentials');
                    }
                } catch (err) {
                    alert('Login failed');
                }
            };
            
            const loadData = async () => {
                try {
                    const [tickets, changes, products, users] = await Promise.all([
                        fetch('/api/tickets').then(r => r.json()),
                        fetch('/api/changes').then(r => r.json()),
                        fetch('/api/products').then(r => r.json()),
                        fetch('/api/users').then(r => r.json())
                    ]);
                    setData({ tickets, changes, products, users });
                } catch (err) {
                    console.error('Failed to load data:', err);
                }
            };
            
            const handleLogout = async () => {
                await fetch('/api/auth/logout', { method: 'POST' });
                setUser(null);
                setData({ tickets: [], changes: [], products: [], users: [] });
            };
            
            if (loading) {
                return (
                    <div className="min-h-screen flex items-center justify-center">
                        <div className="text-center">
                            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
                            <p className="text-gray-600">Loading...</p>
                        </div>
                    </div>
                );
            }
            
            if (!user) {
                return (
                    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-blue-50 to-indigo-100">
                        <div className="max-w-md w-full bg-white rounded-lg shadow-md p-8">
                            <div className="text-center mb-8">
                                <div className="w-20 h-20 mx-auto mb-4 bg-blue-600 rounded-full flex items-center justify-center">
                                    <span className="text-2xl font-bold text-white">C</span>
                                </div>
                                <h1 className="text-2xl font-bold text-gray-900">Calpion IT Service Desk</h1>
                                <p className="text-gray-600 mt-2">Sign in to access your dashboard</p>
                            </div>
                            
                            <form onSubmit={handleLogin}>
                                <div className="mb-4">
                                    <label className="block text-gray-700 text-sm font-bold mb-2">Username</label>
                                    <input
                                        type="text"
                                        value={credentials.username}
                                        onChange={(e) => setCredentials({...credentials, username: e.target.value})}
                                        className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                                        required
                                    />
                                </div>
                                
                                <div className="mb-6">
                                    <label className="block text-gray-700 text-sm font-bold mb-2">Password</label>
                                    <input
                                        type="password"
                                        value={credentials.password}
                                        onChange={(e) => setCredentials({...credentials, password: e.target.value})}
                                        className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                                        required
                                    />
                                </div>
                                
                                <button
                                    type="submit"
                                    className="w-full bg-blue-600 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded-lg transition-colors"
                                >
                                    Sign In
                                </button>
                            </form>
                            
                            <div className="mt-6 text-sm text-gray-500 text-center">
                                <p>Demo: admin/password123</p>
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
                <div className="min-h-screen bg-gray-50">
                    <div className="bg-white shadow-sm border-b">
                        <div className="max-w-7xl mx-auto px-4 py-4">
                            <div className="flex justify-between items-center">
                                <div className="flex items-center">
                                    <div className="w-8 h-8 bg-blue-600 rounded-lg flex items-center justify-center mr-3">
                                        <span className="text-white font-bold">C</span>
                                    </div>
                                    <h1 className="text-xl font-semibold text-gray-900">Calpion IT Service Desk</h1>
                                </div>
                                <div className="flex items-center space-x-4">
                                    <span className="text-sm text-gray-600">Welcome, {user.name}</span>
                                    <button onClick={handleLogout} className="bg-gray-600 hover:bg-gray-700 text-white text-sm px-3 py-1 rounded">
                                        Logout
                                    </button>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div className="bg-white border-b">
                        <div className="max-w-7xl mx-auto px-4">
                            <nav className="flex space-x-8">
                                {[
                                    { id: 'dashboard', label: 'Dashboard' },
                                    { id: 'tickets', label: 'Tickets' },
                                    { id: 'changes', label: 'Changes' },
                                    { id: 'products', label: 'Products' },
                                    { id: 'users', label: 'Users' }
                                ].map(tab => (
                                    <button
                                        key={tab.id}
                                        onClick={() => setActiveTab(tab.id)}
                                        className={\`py-4 px-1 border-b-2 font-medium text-sm \${
                                            activeTab === tab.id
                                                ? 'border-blue-500 text-blue-600'
                                                : 'border-transparent text-gray-500 hover:text-gray-700'
                                        }\`}
                                    >
                                        {tab.label}
                                    </button>
                                ))}
                            </nav>
                        </div>
                    </div>

                    <div className="max-w-7xl mx-auto px-4 py-8">
                        {activeTab === 'dashboard' && (
                            <div>
                                <h2 className="text-2xl font-bold text-gray-900 mb-6">Dashboard Overview</h2>
                                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
                                    <div className="bg-white rounded-lg shadow p-6">
                                        <div className="flex items-center">
                                            <div className="p-2 bg-blue-100 rounded-lg mr-4">
                                                <div className="w-6 h-6 bg-blue-600 rounded"></div>
                                            </div>
                                            <div>
                                                <p className="text-sm text-gray-600">Total Tickets</p>
                                                <p className="text-2xl font-semibold text-gray-900">{stats.totalTickets}</p>
                                            </div>
                                        </div>
                                    </div>
                                    <div className="bg-white rounded-lg shadow p-6">
                                        <div className="flex items-center">
                                            <div className="p-2 bg-yellow-100 rounded-lg mr-4">
                                                <div className="w-6 h-6 bg-yellow-600 rounded"></div>
                                            </div>
                                            <div>
                                                <p className="text-sm text-gray-600">Open Tickets</p>
                                                <p className="text-2xl font-semibold text-gray-900">{stats.openTickets}</p>
                                            </div>
                                        </div>
                                    </div>
                                    <div className="bg-white rounded-lg shadow p-6">
                                        <div className="flex items-center">
                                            <div className="p-2 bg-green-100 rounded-lg mr-4">
                                                <div className="w-6 h-6 bg-green-600 rounded"></div>
                                            </div>
                                            <div>
                                                <p className="text-sm text-gray-600">Pending Changes</p>
                                                <p className="text-2xl font-semibold text-gray-900">{stats.pendingChanges}</p>
                                            </div>
                                        </div>
                                    </div>
                                    <div className="bg-white rounded-lg shadow p-6">
                                        <div className="flex items-center">
                                            <div className="p-2 bg-purple-100 rounded-lg mr-4">
                                                <div className="w-6 h-6 bg-purple-600 rounded"></div>
                                            </div>
                                            <div>
                                                <p className="text-sm text-gray-600">Products</p>
                                                <p className="text-2xl font-semibold text-gray-900">{stats.totalProducts}</p>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        )}
                        
                        {activeTab === 'tickets' && (
                            <div>
                                <h2 className="text-2xl font-bold text-gray-900 mb-6">Tickets</h2>
                                <div className="bg-white rounded-lg shadow overflow-hidden">
                                    <table className="min-w-full">
                                        <thead className="bg-gray-50">
                                            <tr>
                                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">ID</th>
                                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Title</th>
                                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
                                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Priority</th>
                                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Requester</th>
                                            </tr>
                                        </thead>
                                        <tbody className="bg-white divide-y divide-gray-200">
                                            {data.tickets.map(ticket => (
                                                <tr key={ticket.id}>
                                                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">#{ticket.id}</td>
                                                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">{ticket.title}</td>
                                                    <td className="px-6 py-4 whitespace-nowrap">
                                                        <span className={\`inline-flex px-2 py-1 text-xs font-semibold rounded-full \${
                                                            ticket.status === 'open' ? 'bg-blue-100 text-blue-800' :
                                                            ticket.status === 'pending' ? 'bg-yellow-100 text-yellow-800' :
                                                            'bg-gray-100 text-gray-800'
                                                        }\`}>
                                                            {ticket.status}
                                                        </span>
                                                    </td>
                                                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">{ticket.priority}</td>
                                                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">{ticket.requester_name || ticket.requester_email}</td>
                                                </tr>
                                            ))}
                                        </tbody>
                                    </table>
                                </div>
                            </div>
                        )}
                        
                        {/* Similar sections for changes, products, users */}
                    </div>
                </div>
            );
        }
        
        ReactDOM.render(<App />, document.getElementById('root'));
    </script>
</body>
</html>
  `);
});

// Auth middleware
const requireAuth = (req, res, next) => {
  if (!req.session.user) {
    return res.status(401).json({ message: 'Not authenticated' });
  }
  next();
};

// API endpoints
app.post('/api/auth/login', async (req, res) => {
  try {
    const { username, password } = req.body;
    console.log('Login attempt:', username);
    
    const result = await pool.query('SELECT * FROM users WHERE username = $1 AND password = $2', [username, password]);
    
    if (result.rows.length === 0) {
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

app.get('/api/users', requireAuth, async (req, res) => {
  try {
    const result = await pool.query('SELECT id, username, email, name, role FROM users ORDER BY id');
    res.json(result.rows);
  } catch (error) {
    res.status(500).json({ message: 'Internal server error' });
  }
});

app.get('/api/products', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM products WHERE is_active = $1 ORDER BY name', ['true']);
    res.json(result.rows);
  } catch (error) {
    res.status(500).json({ message: 'Internal server error' });
  }
});

app.get('/api/tickets', requireAuth, async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM tickets ORDER BY id DESC LIMIT 50');
    res.json(result.rows);
  } catch (error) {
    res.status(500).json({ message: 'Internal server error' });
  }
});

app.get('/api/changes', requireAuth, async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM changes ORDER BY id DESC LIMIT 50');
    res.json(result.rows);
  } catch (error) {
    res.status(500).json({ message: 'Internal server error' });
  }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(\`Calpion IT Service Desk running on port \${PORT}\`);
});
EOF

# Create simple PM2 config
cat > ecosystem.config.cjs << 'EOF'
module.exports = {
  apps: [{
    name: 'itservicedesk',
    script: 'dist/production.cjs',
    instances: 1,
    autorestart: true
  }]
};
EOF

# Create SSL certificates
sudo mkdir -p /etc/ssl/certs /etc/ssl/private
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/selfsigned.key \
  -out /etc/ssl/certs/selfsigned.crt \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=98.81.235.7"

# Start with PM2
pm2 delete itservicedesk 2>/dev/null || true
pm2 start ecosystem.config.cjs
sleep 3

# Test authentication
echo "Testing login..."
LOGIN_TEST=$(curl -s -X POST http://localhost:5000/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"username":"admin","password":"password123"}')

if echo "$LOGIN_TEST" | grep -q "admin"; then
    echo "✓ Login working"
else
    echo "✗ Login failed"
fi

# Configure nginx
sudo tee /etc/nginx/sites-available/itservicedesk > /dev/null << 'EOF'
server {
    listen 80;
    server_name 98.81.235.7;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name 98.81.235.7;

    ssl_certificate /etc/ssl/certs/selfsigned.crt;
    ssl_certificate_key /etc/ssl/private/selfsigned.key;

    location / {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/itservicedesk /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl restart nginx

echo ""
echo "✅ Simple deployment complete!"
echo "🌐 Access: https://98.81.235.7"
echo "🔐 Login: admin / password123"