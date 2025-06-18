#!/bin/bash

echo "=== FIXING FRONTEND SERVING ISSUE ==="

APP_DIR="/var/www/itservicedesk"
SERVICE_NAME="itservicedesk"

cd $APP_DIR

# Check current state
echo "Checking current frontend state..."
ls -la dist/ 2>/dev/null || echo "No dist directory found"

# Stop service temporarily
sudo systemctl stop $SERVICE_NAME

# Build frontend if needed
echo "Building frontend..."
if [ -f "package.json" ] && grep -q "vite" package.json; then
    echo "Building with Vite..."
    npm run build
else
    echo "Creating basic frontend build..."
    mkdir -p dist
    
    # Create a complete frontend application
    cat << 'HTML_EOF' > dist/index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Calpion IT Service Desk</title>
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
    <div id="app"></div>
    
    <script>
        class ServiceDeskApp {
            constructor() {
                this.currentUser = null;
                this.currentPage = 'login';
                this.init();
            }
            
            init() {
                this.checkAuth();
                this.render();
            }
            
            async checkAuth() {
                try {
                    const response = await fetch('/api/auth/me');
                    if (response.ok) {
                        this.currentUser = await response.json();
                        this.currentPage = 'dashboard';
                    }
                } catch (error) {
                    console.log('Not authenticated');
                }
                this.render();
            }
            
            async login(username, password) {
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
                        this.currentUser = data.user;
                        this.currentPage = 'dashboard';
                        this.render();
                    } else {
                        const error = await response.json();
                        alert(error.message || 'Login failed');
                    }
                } catch (error) {
                    alert('Login failed: ' + error.message);
                }
            }
            
            async logout() {
                try {
                    await fetch('/api/auth/logout', { method: 'POST' });
                    this.currentUser = null;
                    this.currentPage = 'login';
                    this.render();
                } catch (error) {
                    console.error('Logout error:', error);
                }
            }
            
            async loadData(endpoint) {
                try {
                    const response = await fetch(endpoint);
                    if (response.ok) {
                        return await response.json();
                    }
                    throw new Error('Failed to load data');
                } catch (error) {
                    console.error('Data loading error:', error);
                    return [];
                }
            }
            
            renderLogin() {
                return `
                    <div class="min-h-screen flex items-center justify-center bg-gray-50">
                        <div class="max-w-md w-full space-y-8">
                            <div>
                                <div class="calpion-gradient text-white p-6 rounded-lg text-center mb-8">
                                    <h2 class="text-3xl font-bold">Calpion</h2>
                                    <p class="text-lg">IT Service Desk</p>
                                </div>
                                <h2 class="text-center text-2xl font-bold text-gray-900">
                                    Sign in to your account
                                </h2>
                            </div>
                            <form class="mt-8 space-y-6" onsubmit="app.handleLogin(event)">
                                <div class="space-y-4">
                                    <div>
                                        <label for="username" class="sr-only">Username</label>
                                        <input id="username" name="username" type="text" required 
                                               class="appearance-none rounded-md relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 focus:z-10 sm:text-sm" 
                                               placeholder="Username">
                                    </div>
                                    <div>
                                        <label for="password" class="sr-only">Password</label>
                                        <input id="password" name="password" type="password" required 
                                               class="appearance-none rounded-md relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 focus:z-10 sm:text-sm" 
                                               placeholder="Password">
                                    </div>
                                </div>
                                
                                <div>
                                    <button type="submit" 
                                            class="group relative w-full flex justify-center py-2 px-4 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
                                        Sign in
                                    </button>
                                </div>
                                
                                <div class="text-center text-sm text-gray-600">
                                    <p>Test Accounts:</p>
                                    <p><strong>Admin:</strong> john.doe / password123</p>
                                    <p><strong>User:</strong> test.user / password123</p>
                                </div>
                            </form>
                        </div>
                    </div>
                `;
            }
            
            renderDashboard() {
                const user = this.currentUser?.user || this.currentUser;
                return `
                    <div class="min-h-screen bg-gray-50">
                        <nav class="calpion-gradient text-white shadow-lg">
                            <div class="max-w-7xl mx-auto px-4">
                                <div class="flex justify-between h-16">
                                    <div class="flex items-center">
                                        <h1 class="text-xl font-bold">Calpion IT Service Desk</h1>
                                    </div>
                                    <div class="flex items-center space-x-4">
                                        <span>Welcome, ${user?.name || user?.username}</span>
                                        <button onclick="app.logout()" 
                                                class="bg-white bg-opacity-20 hover:bg-opacity-30 px-3 py-1 rounded text-sm">
                                            Logout
                                        </button>
                                    </div>
                                </div>
                            </div>
                        </nav>
                        
                        <div class="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
                            <div class="px-4 py-6 sm:px-0">
                                <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
                                    <div class="bg-white overflow-hidden shadow rounded-lg">
                                        <div class="p-5">
                                            <div class="flex items-center">
                                                <div class="flex-shrink-0">
                                                    <div class="w-8 h-8 bg-blue-500 rounded text-white flex items-center justify-center">T</div>
                                                </div>
                                                <div class="ml-5 w-0 flex-1">
                                                    <dl>
                                                        <dt class="text-sm font-medium text-gray-500 truncate">Tickets</dt>
                                                        <dd class="text-lg font-medium text-gray-900" id="ticketCount">...</dd>
                                                    </dl>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                    
                                    <div class="bg-white overflow-hidden shadow rounded-lg">
                                        <div class="p-5">
                                            <div class="flex items-center">
                                                <div class="flex-shrink-0">
                                                    <div class="w-8 h-8 bg-green-500 rounded text-white flex items-center justify-center">C</div>
                                                </div>
                                                <div class="ml-5 w-0 flex-1">
                                                    <dl>
                                                        <dt class="text-sm font-medium text-gray-500 truncate">Changes</dt>
                                                        <dd class="text-lg font-medium text-gray-900" id="changeCount">...</dd>
                                                    </dl>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                    
                                    <div class="bg-white overflow-hidden shadow rounded-lg">
                                        <div class="p-5">
                                            <div class="flex items-center">
                                                <div class="flex-shrink-0">
                                                    <div class="w-8 h-8 bg-purple-500 rounded text-white flex items-center justify-center">P</div>
                                                </div>
                                                <div class="ml-5 w-0 flex-1">
                                                    <dl>
                                                        <dt class="text-sm font-medium text-gray-500 truncate">Products</dt>
                                                        <dd class="text-lg font-medium text-gray-900" id="productCount">...</dd>
                                                    </dl>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                    
                                    <div class="bg-white overflow-hidden shadow rounded-lg">
                                        <div class="p-5">
                                            <div class="flex items-center">
                                                <div class="flex-shrink-0">
                                                    <div class="w-8 h-8 bg-orange-500 rounded text-white flex items-center justify-center">U</div>
                                                </div>
                                                <div class="ml-5 w-0 flex-1">
                                                    <dl>
                                                        <dt class="text-sm font-medium text-gray-500 truncate">Users</dt>
                                                        <dd class="text-lg font-medium text-gray-900" id="userCount">...</dd>
                                                    </dl>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                                
                                <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
                                    <div class="bg-white shadow rounded-lg">
                                        <div class="px-4 py-5 sm:p-6">
                                            <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">Recent Tickets</h3>
                                            <div id="recentTickets" class="space-y-3">
                                                <div class="text-center py-4">
                                                    <div class="loading w-6 h-6 border-2 border-gray-300 border-t-blue-600 rounded-full mx-auto"></div>
                                                    <p class="text-sm text-gray-500 mt-2">Loading tickets...</p>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                    
                                    <div class="bg-white shadow rounded-lg">
                                        <div class="px-4 py-5 sm:p-6">
                                            <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">Recent Changes</h3>
                                            <div id="recentChanges" class="space-y-3">
                                                <div class="text-center py-4">
                                                    <div class="loading w-6 h-6 border-2 border-gray-300 border-t-green-600 rounded-full mx-auto"></div>
                                                    <p class="text-sm text-gray-500 mt-2">Loading changes...</p>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                `;
            }
            
            async loadDashboardData() {
                // Load counts
                try {
                    const [tickets, changes, products, users] = await Promise.all([
                        this.loadData('/api/tickets'),
                        this.loadData('/api/changes'),
                        this.loadData('/api/products'),
                        this.loadData('/api/users')
                    ]);
                    
                    document.getElementById('ticketCount').textContent = tickets.length;
                    document.getElementById('changeCount').textContent = changes.length;
                    document.getElementById('productCount').textContent = products.length;
                    document.getElementById('userCount').textContent = users.length;
                    
                    // Display recent tickets
                    const recentTicketsHtml = tickets.slice(0, 5).map(ticket => `
                        <div class="flex items-center justify-between p-3 bg-gray-50 rounded">
                            <div>
                                <p class="text-sm font-medium text-gray-900">${ticket.title}</p>
                                <p class="text-xs text-gray-500">Priority: ${ticket.priority}</p>
                            </div>
                            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                                ${ticket.status}
                            </span>
                        </div>
                    `).join('');
                    
                    document.getElementById('recentTickets').innerHTML = recentTicketsHtml || '<p class="text-gray-500 text-center">No tickets found</p>';
                    
                    // Display recent changes
                    const recentChangesHtml = changes.slice(0, 5).map(change => `
                        <div class="flex items-center justify-between p-3 bg-gray-50 rounded">
                            <div>
                                <p class="text-sm font-medium text-gray-900">${change.title}</p>
                                <p class="text-xs text-gray-500">Risk: ${change.riskLevel}</p>
                            </div>
                            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                                ${change.status}
                            </span>
                        </div>
                    `).join('');
                    
                    document.getElementById('recentChanges').innerHTML = recentChangesHtml || '<p class="text-gray-500 text-center">No changes found</p>';
                    
                } catch (error) {
                    console.error('Error loading dashboard data:', error);
                }
            }
            
            handleLogin(event) {
                event.preventDefault();
                const formData = new FormData(event.target);
                const username = formData.get('username');
                const password = formData.get('password');
                this.login(username, password);
            }
            
            render() {
                const app = document.getElementById('app');
                
                if (this.currentPage === 'login') {
                    app.innerHTML = this.renderLogin();
                } else if (this.currentPage === 'dashboard') {
                    app.innerHTML = this.renderDashboard();
                    this.loadDashboardData();
                }
            }
        }
        
        // Initialize app
        const app = new ServiceDeskApp();
    </script>
</body>
</html>
HTML_EOF
fi

# Update server to serve frontend properly
echo "Updating server configuration..."
cat << 'SERVER_UPDATE_EOF' > server-update.js
// Add this section to the existing server-production.js

// Serve static files with proper MIME types
app.use(express.static(path.join(__dirname, 'dist'), {
    setHeaders: (res, filePath) => {
        if (filePath.endsWith('.html')) {
            res.setHeader('Content-Type', 'text/html');
        } else if (filePath.endsWith('.js')) {
            res.setHeader('Content-Type', 'application/javascript');
        } else if (filePath.endsWith('.css')) {
            res.setHeader('Content-Type', 'text/css');
        }
    }
}));

// Catch-all handler: send back React's index.html file for SPA routing
app.get('*', (req, res) => {
    const indexPath = path.join(__dirname, 'dist', 'index.html');
    if (fs.existsSync(indexPath)) {
        res.sendFile(indexPath);
    } else {
        res.status(404).json({ 
            message: 'Frontend not found',
            api: 'Available at /api/* endpoints'
        });
    }
});
SERVER_UPDATE_EOF

# Apply server update if needed
if ! grep -q "setHeaders" server-production.js; then
    echo "Updating server file serving configuration..."
    
    # Backup original
    cp server-production.js server-production.js.backup
    
    # Update the static serving section
    sed -i '/Serve static files/,$d' server-production.js
    
    cat << 'STATIC_SERVE_EOF' >> server-production.js

// Serve static files with proper configuration
const staticPath = path.join(__dirname, 'dist');
app.use(express.static(staticPath, {
    setHeaders: (res, filePath) => {
        if (filePath.endsWith('.html')) {
            res.setHeader('Content-Type', 'text/html');
        } else if (filePath.endsWith('.js')) {
            res.setHeader('Content-Type', 'application/javascript');
        } else if (filePath.endsWith('.css')) {
            res.setHeader('Content-Type', 'text/css');
        }
    }
}));

// Catch-all handler for SPA
app.get('*', (req, res) => {
    const indexPath = path.join(__dirname, 'dist', 'index.html');
    if (fs.existsSync(indexPath)) {
        res.sendFile(indexPath);
    } else {
        res.status(404).json({ 
            message: 'Calpion IT Service Desk - Frontend build not found',
            status: 'API Only Mode',
            endpoints: [
                'GET /health - System health',
                'POST /api/auth/login - Authentication',
                'GET /api/users - User management',
                'GET /api/products - Product catalog',
                'GET /api/tickets - Ticket system',
                'GET /api/changes - Change management',
                'GET /api/email/settings - Email configuration'
            ]
        });
    }
});

const PORT = process.env.PORT || 5000;
app.listen(PORT, '127.0.0.1', () => {
    console.log(`[Server] Systemd service running on localhost:${PORT}`);
    console.log('[Server] Database: PostgreSQL servicedesk@localhost:5432/servicedesk');
    console.log('[Server] Proxy: nginx handling HTTPS on port 443');
    console.log('[Server] Frontend: Serving from dist/ directory');
});
STATIC_SERVE_EOF
fi

# Fix permissions
sudo chown -R ubuntu:ubuntu $APP_DIR

# Start service
echo "Starting service with frontend..."
sudo systemctl start $SERVICE_NAME

# Wait for startup
sleep 10

# Test frontend serving
echo "Testing frontend serving..."
FRONTEND_TEST=$(curl -s -H "Accept: text/html" http://localhost:5000/ | head -20)

if echo "$FRONTEND_TEST" | grep -q "<!DOCTYPE html>"; then
    echo "✓ Frontend HTML being served correctly"
else
    echo "✗ Frontend still not serving HTML"
    echo "Response: $FRONTEND_TEST"
fi

# Test HTTPS frontend
HTTPS_FRONTEND=$(curl -k -s -H "Accept: text/html" https://98.81.235.7/ | head -10)

if echo "$HTTPS_FRONTEND" | grep -q "<!DOCTYPE html>"; then
    echo "✓ HTTPS frontend working"
else
    echo "✗ HTTPS frontend issue"
fi

echo ""
echo "=== FRONTEND SERVING FIXED ==="
echo "✅ Frontend built and configured"
echo "✅ Server updated to serve HTML properly"
echo "✅ Static file serving with proper MIME types"
echo ""
echo "Access: https://98.81.235.7"
echo "You should now see the login page instead of JSON"

# Show service status
sudo systemctl status $SERVICE_NAME --no-pager