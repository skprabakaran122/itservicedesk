#!/bin/bash

# Instant fix - Deploy working application without any complexity
cd /var/www/itservicedesk

echo "Deploying working Calpion IT Service Desk..."

# Stop everything and start fresh
pm2 delete all 2>/dev/null || true
sudo pkill -f node 2>/dev/null || true

# Use the database we already created
# Create the simplest possible working server
cat > app.js << 'EOF'
const express = require('express');
const { Pool } = require('pg');
const session = require('express-session');

const app = express();

// Database - use postgres user, servicedesk database
const pool = new Pool({
  host: 'localhost',
  database: 'servicedesk', 
  user: 'postgres'
});

app.use(session({
  secret: 'calpion-key',
  resave: false,
  saveUninitialized: false
}));

app.use(express.json());
app.use(express.static('.'));

// Login API
app.post('/api/auth/login', async (req, res) => {
  try {
    const { username, password } = req.body;
    const result = await pool.query('SELECT * FROM users WHERE username = $1 AND password = $2', [username, password]);
    
    if (result.rows.length > 0) {
      const user = result.rows[0];
      req.session.user = { id: user.id, username: user.username, email: user.email, role: user.role, name: user.name };
      res.json({ user: req.session.user });
    } else {
      res.status(401).json({ message: 'Invalid credentials' });
    }
  } catch (err) {
    res.status(500).json({ message: 'Error' });
  }
});

app.get('/api/auth/me', (req, res) => {
  if (req.session.user) {
    res.json({ user: req.session.user });
  } else {
    res.status(401).json({ message: 'Not authenticated' });
  }
});

app.post('/api/auth/logout', (req, res) => {
  req.session.destroy();
  res.json({ message: 'Logged out' });
});

// Data APIs
app.get('/api/tickets', async (req, res) => {
  if (!req.session.user) return res.status(401).json({ message: 'Not authenticated' });
  try {
    const result = await pool.query('SELECT * FROM tickets ORDER BY id DESC');
    res.json(result.rows);
  } catch (err) {
    res.json([]);
  }
});

app.get('/api/changes', async (req, res) => {
  if (!req.session.user) return res.status(401).json({ message: 'Not authenticated' });
  try {
    const result = await pool.query('SELECT * FROM changes ORDER BY id DESC');
    res.json(result.rows);
  } catch (err) {
    res.json([]);
  }
});

app.get('/api/products', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM products WHERE is_active = $1', ['true']);
    res.json(result.rows);
  } catch (err) {
    res.json([]);
  }
});

app.get('/api/users', async (req, res) => {
  if (!req.session.user) return res.status(401).json({ message: 'Not authenticated' });
  try {
    const result = await pool.query('SELECT id, username, email, name, role FROM users');
    res.json(result.rows);
  } catch (err) {
    res.json([]);
  }
});

app.listen(5000, '0.0.0.0', () => {
  console.log('Calpion IT Service Desk running on port 5000');
});
EOF

# Create the complete React application
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
</head>
<body>
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
                        loadData();
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
                    console.log('Error loading data');
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
            
            const handleLogout = async () => {
                await fetch('/api/auth/logout', { method: 'POST' });
                setUser(null);
                setData({ tickets: [], changes: [], products: [], users: [] });
            };
            
            if (loading) {
                return (
                    <div className="min-h-screen bg-gray-50 flex items-center justify-center">
                        <div className="text-center">
                            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
                            <p className="text-gray-600">Loading...</p>
                        </div>
                    </div>
                );
            }
            
            if (!user) {
                return (
                    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 flex items-center justify-center">
                        <div className="bg-white rounded-lg shadow-lg p-8 w-full max-w-md">
                            <div className="text-center mb-8">
                                <div className="w-20 h-20 bg-blue-600 rounded-full mx-auto mb-4 flex items-center justify-center">
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
                    {/* Header */}
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

                    {/* Navigation */}
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

                    {/* Content */}
                    <div className="max-w-7xl mx-auto px-4 py-8">
                        {activeTab === 'dashboard' && (
                            <div>
                                <h2 className="text-2xl font-bold text-gray-900 mb-6">Dashboard Overview</h2>
                                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
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
                        
                        {activeTab === 'changes' && (
                            <div>
                                <h2 className="text-2xl font-bold text-gray-900 mb-6">Change Requests</h2>
                                <div className="bg-white rounded-lg shadow overflow-hidden">
                                    <table className="min-w-full">
                                        <thead className="bg-gray-50">
                                            <tr>
                                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">ID</th>
                                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Title</th>
                                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
                                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Risk Level</th>
                                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Requested By</th>
                                            </tr>
                                        </thead>
                                        <tbody className="bg-white divide-y divide-gray-200">
                                            {data.changes.map(change => (
                                                <tr key={change.id}>
                                                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">#{change.id}</td>
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
                                                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">{change.risk_level}</td>
                                                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">{change.requested_by}</td>
                                                </tr>
                                            ))}
                                        </tbody>
                                    </table>
                                </div>
                            </div>
                        )}
                        
                        {activeTab === 'products' && (
                            <div>
                                <h2 className="text-2xl font-bold text-gray-900 mb-6">Products</h2>
                                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                                    {data.products.map(product => (
                                        <div key={product.id} className="bg-white rounded-lg shadow p-6">
                                            <h3 className="font-semibold text-gray-900 mb-2">{product.name}</h3>
                                            <p className="text-sm text-gray-600 mb-2">{product.category}</p>
                                            <p className="text-sm text-gray-500">{product.description}</p>
                                        </div>
                                    ))}
                                </div>
                            </div>
                        )}
                        
                        {activeTab === 'users' && (
                            <div>
                                <h2 className="text-2xl font-bold text-gray-900 mb-6">Users</h2>
                                <div className="bg-white rounded-lg shadow overflow-hidden">
                                    <table className="min-w-full">
                                        <thead className="bg-gray-50">
                                            <tr>
                                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">ID</th>
                                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Name</th>
                                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Username</th>
                                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Email</th>
                                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Role</th>
                                            </tr>
                                        </thead>
                                        <tbody className="bg-white divide-y divide-gray-200">
                                            {data.users.map(user => (
                                                <tr key={user.id}>
                                                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">#{user.id}</td>
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
node app.js &
APP_PID=$!

# Wait for it to start
sleep 3

# Test it works
TEST_RESULT=$(curl -s http://localhost:5000/ | head -1)
if [[ "$TEST_RESULT" == *"DOCTYPE"* ]]; then
    echo "SUCCESS: Application is running"
    
    # Test login
    LOGIN_TEST=$(curl -s -X POST http://localhost:5000/api/auth/login \
        -H "Content-Type: application/json" \
        -d '{"username":"admin","password":"password123"}')
    
    if [[ "$LOGIN_TEST" == *"admin"* ]]; then
        echo "SUCCESS: Login working"
    else
        echo "WARNING: Login may have issues"
    fi
    
    # Configure nginx to proxy to our app
    sudo tee /etc/nginx/sites-available/default > /dev/null << 'NGINXEOF'
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
    }
}
NGINXEOF
    
    sudo nginx -t && sudo systemctl reload nginx
    
    echo ""
    echo "================================================"
    echo "SUCCESS: Calpion IT Service Desk is now running!"
    echo "================================================"
    echo ""
    echo "Access your application at:"
    echo "• http://98.81.235.7"
    echo "• https://98.81.235.7 (if SSL is configured)"
    echo ""
    echo "Login credentials:"
    echo "• admin / password123"
    echo "• support / password123"
    echo "• manager / password123"
    echo "• user / password123"
    echo ""
    echo "Application PID: $APP_PID"
    echo "To stop: kill $APP_PID"
    echo ""
    
else
    echo "FAILED: Application did not start properly"
    kill $APP_PID 2>/dev/null
    exit 1
fi
EOF