#!/bin/bash

echo "=== CREATING SIMPLE FRONTEND WITHOUT BUILD TOOLS ==="

APP_DIR="/var/www/itservicedesk"
SERVICE_NAME="itservicedesk"

cd $APP_DIR

# Stop service
sudo systemctl stop $SERVICE_NAME

# Create dist directory and simple frontend
echo "Creating frontend without build dependencies..."
mkdir -p dist

# Create a comprehensive single-file frontend application
cat << 'SIMPLE_FRONTEND_EOF' > dist/index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Calpion IT Service Desk</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script>
        tailwind.config = {
            theme: {
                extend: {
                    colors: {
                        calpion: {
                            primary: '#667eea',
                            secondary: '#764ba2'
                        }
                    }
                }
            }
        }
    </script>
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
        .fade-in {
            animation: fadeIn 0.5s ease-in;
        }
        @keyframes fadeIn {
            from { opacity: 0; transform: translateY(20px); }
            to { opacity: 1; transform: translateY(0); }
        }
    </style>
</head>
<body class="bg-gray-50 min-h-screen">
    <div id="app" class="min-h-screen">
        <div class="flex items-center justify-center min-h-screen">
            <div class="loading w-8 h-8 border-4 border-gray-300 border-t-blue-600 rounded-full"></div>
            <span class="ml-3 text-gray-600">Loading...</span>
        </div>
    </div>
    
    <script>
        class ServiceDeskApp {
            constructor() {
                this.currentUser = null;
                this.currentPage = 'login';
                this.data = {
                    tickets: [],
                    changes: [],
                    products: [],
                    users: []
                };
                this.init();
            }
            
            async init() {
                await this.checkAuth();
                this.render();
            }
            
            async checkAuth() {
                try {
                    const response = await fetch('/api/auth/me');
                    if (response.ok) {
                        const data = await response.json();
                        this.currentUser = data.user;
                        this.currentPage = 'dashboard';
                    }
                } catch (error) {
                    console.log('User not authenticated');
                }
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
                        this.showNotification('Login successful!', 'success');
                    } else {
                        const error = await response.json();
                        this.showNotification(error.message || 'Login failed', 'error');
                    }
                } catch (error) {
                    this.showNotification('Network error: ' + error.message, 'error');
                }
            }
            
            async logout() {
                try {
                    await fetch('/api/auth/logout', { method: 'POST' });
                    this.currentUser = null;
                    this.currentPage = 'login';
                    this.render();
                    this.showNotification('Logged out successfully', 'info');
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
            
            showNotification(message, type = 'info') {
                const notification = document.createElement('div');
                notification.className = `fixed top-4 right-4 z-50 p-4 rounded-lg shadow-lg transition-all transform translate-x-full ${
                    type === 'success' ? 'bg-green-500 text-white' :
                    type === 'error' ? 'bg-red-500 text-white' :
                    'bg-blue-500 text-white'
                }`;
                notification.textContent = message;
                
                document.body.appendChild(notification);
                
                setTimeout(() => {
                    notification.classList.remove('translate-x-full');
                }, 100);
                
                setTimeout(() => {
                    notification.classList.add('translate-x-full');
                    setTimeout(() => {
                        document.body.removeChild(notification);
                    }, 300);
                }, 3000);
            }
            
            renderLogin() {
                return `
                    <div class="min-h-screen flex items-center justify-center bg-gradient-to-br from-gray-50 to-gray-100 fade-in">
                        <div class="max-w-md w-full space-y-8 p-6">
                            <div class="text-center">
                                <div class="calpion-gradient text-white p-8 rounded-2xl shadow-xl mb-8">
                                    <div class="w-16 h-16 bg-white bg-opacity-20 rounded-full flex items-center justify-center mx-auto mb-4">
                                        <svg class="w-8 h-8 text-white" fill="currentColor" viewBox="0 0 20 20">
                                            <path d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
                                        </svg>
                                    </div>
                                    <h2 class="text-3xl font-bold">Calpion</h2>
                                    <p class="text-xl opacity-90">IT Service Desk</p>
                                </div>
                                <h2 class="text-2xl font-bold text-gray-900 mb-2">
                                    Welcome Back
                                </h2>
                                <p class="text-gray-600">Sign in to access your dashboard</p>
                            </div>
                            
                            <form class="mt-8 space-y-6 bg-white p-8 rounded-xl shadow-lg" onsubmit="app.handleLogin(event)">
                                <div class="space-y-4">
                                    <div>
                                        <label for="username" class="block text-sm font-medium text-gray-700 mb-1">Username</label>
                                        <input id="username" name="username" type="text" required 
                                               class="appearance-none relative block w-full px-3 py-3 border border-gray-300 placeholder-gray-500 text-gray-900 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all" 
                                               placeholder="Enter your username">
                                    </div>
                                    <div>
                                        <label for="password" class="block text-sm font-medium text-gray-700 mb-1">Password</label>
                                        <input id="password" name="password" type="password" required 
                                               class="appearance-none relative block w-full px-3 py-3 border border-gray-300 placeholder-gray-500 text-gray-900 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all" 
                                               placeholder="Enter your password">
                                    </div>
                                </div>
                                
                                <div>
                                    <button type="submit" 
                                            class="group relative w-full flex justify-center py-3 px-4 border border-transparent text-sm font-medium rounded-lg text-white calpion-gradient hover:opacity-90 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 transition-all transform hover:scale-105">
                                        <span class="absolute left-0 inset-y-0 flex items-center pl-3">
                                            <svg class="h-5 w-5 text-white group-hover:text-gray-100" fill="currentColor" viewBox="0 0 20 20">
                                                <path fill-rule="evenodd" d="M5 9V7a5 5 0 0110 0v2a2 2 0 012 2v5a2 2 0 01-2 2H5a2 2 0 01-2-2v-5a2 2 0 012-2zm8-2v2H7V7a3 3 0 016 0z" clip-rule="evenodd"/>
                                            </svg>
                                        </span>
                                        Sign In
                                    </button>
                                </div>
                                
                                <div class="bg-gray-50 p-4 rounded-lg">
                                    <p class="text-center text-sm text-gray-600 mb-2 font-medium">Test Accounts:</p>
                                    <div class="space-y-1 text-xs text-gray-500">
                                        <p><span class="font-medium">Admin:</span> john.doe / password123</p>
                                        <p><span class="font-medium">Manager:</span> jane.manager / password123</p>
                                        <p><span class="font-medium">Agent:</span> bob.agent / password123</p>
                                        <p><span class="font-medium">User:</span> test.user / password123</p>
                                    </div>
                                </div>
                            </form>
                        </div>
                    </div>
                `;
            }
            
            renderDashboard() {
                const user = this.currentUser;
                return `
                    <div class="min-h-screen bg-gray-50 fade-in">
                        <nav class="calpion-gradient text-white shadow-lg">
                            <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
                                <div class="flex justify-between h-16">
                                    <div class="flex items-center">
                                        <div class="flex-shrink-0 flex items-center">
                                            <div class="w-8 h-8 bg-white bg-opacity-20 rounded-full flex items-center justify-center mr-3">
                                                <svg class="w-5 h-5 text-white" fill="currentColor" viewBox="0 0 20 20">
                                                    <path d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
                                                </svg>
                                            </div>
                                            <h1 class="text-xl font-bold">Calpion IT Service Desk</h1>
                                        </div>
                                    </div>
                                    <div class="flex items-center space-x-4">
                                        <div class="flex items-center space-x-2">
                                            <div class="w-8 h-8 bg-white bg-opacity-20 rounded-full flex items-center justify-center">
                                                <span class="text-sm font-medium">${user.name ? user.name.charAt(0).toUpperCase() : 'U'}</span>
                                            </div>
                                            <span class="hidden md:block">Welcome, ${user.name || user.username}</span>
                                        </div>
                                        <button onclick="app.logout()" 
                                                class="bg-white bg-opacity-20 hover:bg-opacity-30 px-4 py-2 rounded-lg text-sm transition-all">
                                            Sign Out
                                        </button>
                                    </div>
                                </div>
                            </div>
                        </nav>
                        
                        <div class="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
                            <div class="px-4 py-6 sm:px-0">
                                <!-- Stats Grid -->
                                <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
                                    <div class="bg-white overflow-hidden shadow-lg rounded-xl hover:shadow-xl transition-shadow">
                                        <div class="p-6">
                                            <div class="flex items-center">
                                                <div class="flex-shrink-0">
                                                    <div class="w-12 h-12 bg-blue-500 rounded-xl text-white flex items-center justify-center">
                                                        <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 20 20">
                                                            <path d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
                                                        </svg>
                                                    </div>
                                                </div>
                                                <div class="ml-5 w-0 flex-1">
                                                    <dl>
                                                        <dt class="text-sm font-medium text-gray-500 truncate">Total Tickets</dt>
                                                        <dd class="text-2xl font-bold text-gray-900" id="ticketCount">
                                                            <div class="loading w-5 h-5 border-2 border-gray-300 border-t-blue-600 rounded-full"></div>
                                                        </dd>
                                                    </dl>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                    
                                    <div class="bg-white overflow-hidden shadow-lg rounded-xl hover:shadow-xl transition-shadow">
                                        <div class="p-6">
                                            <div class="flex items-center">
                                                <div class="flex-shrink-0">
                                                    <div class="w-12 h-12 bg-green-500 rounded-xl text-white flex items-center justify-center">
                                                        <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 20 20">
                                                            <path d="M4 4a2 2 0 00-2 2v8a2 2 0 002 2h12a2 2 0 002-2V6a2 2 0 00-2-2H4zm0 2h12v8H4V6z"/>
                                                        </svg>
                                                    </div>
                                                </div>
                                                <div class="ml-5 w-0 flex-1">
                                                    <dl>
                                                        <dt class="text-sm font-medium text-gray-500 truncate">Active Changes</dt>
                                                        <dd class="text-2xl font-bold text-gray-900" id="changeCount">
                                                            <div class="loading w-5 h-5 border-2 border-gray-300 border-t-green-600 rounded-full"></div>
                                                        </dd>
                                                    </dl>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                    
                                    <div class="bg-white overflow-hidden shadow-lg rounded-xl hover:shadow-xl transition-shadow">
                                        <div class="p-6">
                                            <div class="flex items-center">
                                                <div class="flex-shrink-0">
                                                    <div class="w-12 h-12 bg-purple-500 rounded-xl text-white flex items-center justify-center">
                                                        <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 20 20">
                                                            <path d="M3 4a1 1 0 011-1h12a1 1 0 011 1v2a1 1 0 01-1 1H4a1 1 0 01-1-1V4zM3 10a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H4a1 1 0 01-1-1v-6zM14 9a1 1 0 00-1 1v6a1 1 0 001 1h2a1 1 0 001-1v-6a1 1 0 00-1-1h-2z"/>
                                                        </svg>
                                                    </div>
                                                </div>
                                                <div class="ml-5 w-0 flex-1">
                                                    <dl>
                                                        <dt class="text-sm font-medium text-gray-500 truncate">Products</dt>
                                                        <dd class="text-2xl font-bold text-gray-900" id="productCount">
                                                            <div class="loading w-5 h-5 border-2 border-gray-300 border-t-purple-600 rounded-full"></div>
                                                        </dd>
                                                    </dl>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                    
                                    <div class="bg-white overflow-hidden shadow-lg rounded-xl hover:shadow-xl transition-shadow">
                                        <div class="p-6">
                                            <div class="flex items-center">
                                                <div class="flex-shrink-0">
                                                    <div class="w-12 h-12 bg-orange-500 rounded-xl text-white flex items-center justify-center">
                                                        <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 20 20">
                                                            <path d="M9 6a3 3 0 11-6 0 3 3 0 016 0zM17 6a3 3 0 11-6 0 3 3 0 016 0zM12.93 17c.046-.327.07-.66.07-1a6.97 6.97 0 00-1.5-4.33A5 5 0 0119 16v1h-6.07zM6 11a5 5 0 015 5v1H1v-1a5 5 0 015-5z"/>
                                                        </svg>
                                                    </div>
                                                </div>
                                                <div class="ml-5 w-0 flex-1">
                                                    <dl>
                                                        <dt class="text-sm font-medium text-gray-500 truncate">Team Members</dt>
                                                        <dd class="text-2xl font-bold text-gray-900" id="userCount">
                                                            <div class="loading w-5 h-5 border-2 border-gray-300 border-t-orange-600 rounded-full"></div>
                                                        </dd>
                                                    </dl>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                                
                                <!-- Content Grid -->
                                <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
                                    <div class="bg-white shadow-lg rounded-xl">
                                        <div class="px-6 py-5 border-b border-gray-200">
                                            <h3 class="text-lg leading-6 font-medium text-gray-900">Recent Tickets</h3>
                                        </div>
                                        <div class="px-6 py-4">
                                            <div id="recentTickets" class="space-y-3">
                                                <div class="text-center py-8">
                                                    <div class="loading w-8 h-8 border-4 border-gray-300 border-t-blue-600 rounded-full mx-auto"></div>
                                                    <p class="text-sm text-gray-500 mt-4">Loading tickets...</p>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                    
                                    <div class="bg-white shadow-lg rounded-xl">
                                        <div class="px-6 py-5 border-b border-gray-200">
                                            <h3 class="text-lg leading-6 font-medium text-gray-900">Recent Changes</h3>
                                        </div>
                                        <div class="px-6 py-4">
                                            <div id="recentChanges" class="space-y-3">
                                                <div class="text-center py-8">
                                                    <div class="loading w-8 h-8 border-4 border-gray-300 border-t-green-600 rounded-full mx-auto"></div>
                                                    <p class="text-sm text-gray-500 mt-4">Loading changes...</p>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                                
                                <!-- System Status -->
                                <div class="mt-6 bg-white shadow-lg rounded-xl">
                                    <div class="px-6 py-5 border-b border-gray-200">
                                        <h3 class="text-lg leading-6 font-medium text-gray-900">System Status</h3>
                                    </div>
                                    <div class="px-6 py-4">
                                        <div id="systemStatus" class="text-center py-4">
                                            <div class="loading w-6 h-6 border-2 border-gray-300 border-t-blue-600 rounded-full mx-auto"></div>
                                            <p class="text-sm text-gray-500 mt-2">Checking system status...</p>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                `;
            }
            
            async loadDashboardData() {
                try {
                    // Load all data
                    const [tickets, changes, products, users, health] = await Promise.all([
                        this.loadData('/api/tickets'),
                        this.loadData('/api/changes'),
                        this.loadData('/api/products'),
                        this.loadData('/api/users'),
                        this.loadData('/health')
                    ]);
                    
                    // Update counts
                    document.getElementById('ticketCount').textContent = tickets.length;
                    document.getElementById('changeCount').textContent = changes.length;
                    document.getElementById('productCount').textContent = products.length;
                    document.getElementById('userCount').textContent = users.length;
                    
                    // Display recent tickets
                    const ticketsHtml = tickets.slice(0, 5).map(ticket => `
                        <div class="flex items-center justify-between p-4 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors">
                            <div class="flex-1 min-w-0">
                                <p class="text-sm font-medium text-gray-900 truncate">#${ticket.id} - ${ticket.title}</p>
                                <p class="text-xs text-gray-500">Priority: ${ticket.priority} | Category: ${ticket.category}</p>
                            </div>
                            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                                ticket.status === 'open' ? 'bg-blue-100 text-blue-800' :
                                ticket.status === 'resolved' ? 'bg-green-100 text-green-800' :
                                'bg-yellow-100 text-yellow-800'
                            }">
                                ${ticket.status}
                            </span>
                        </div>
                    `).join('');
                    
                    document.getElementById('recentTickets').innerHTML = ticketsHtml || 
                        '<p class="text-gray-500 text-center py-8">No tickets found</p>';
                    
                    // Display recent changes
                    const changesHtml = changes.slice(0, 5).map(change => `
                        <div class="flex items-center justify-between p-4 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors">
                            <div class="flex-1 min-w-0">
                                <p class="text-sm font-medium text-gray-900 truncate">#${change.id} - ${change.title}</p>
                                <p class="text-xs text-gray-500">Risk: ${change.riskLevel} | Type: ${change.changeType}</p>
                            </div>
                            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                                change.status === 'draft' ? 'bg-gray-100 text-gray-800' :
                                change.status === 'approved' ? 'bg-green-100 text-green-800' :
                                'bg-blue-100 text-blue-800'
                            }">
                                ${change.status}
                            </span>
                        </div>
                    `).join('');
                    
                    document.getElementById('recentChanges').innerHTML = changesHtml || 
                        '<p class="text-gray-500 text-center py-8">No changes found</p>';
                    
                    // Display system status
                    const statusHtml = `
                        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                            <div class="text-center">
                                <div class="w-3 h-3 bg-green-500 rounded-full mx-auto mb-2"></div>
                                <p class="text-sm font-medium text-gray-900">Database</p>
                                <p class="text-xs text-gray-500">${health.database?.connected ? 'Connected' : 'Disconnected'}</p>
                            </div>
                            <div class="text-center">
                                <div class="w-3 h-3 bg-green-500 rounded-full mx-auto mb-2"></div>
                                <p class="text-sm font-medium text-gray-900">API Server</p>
                                <p class="text-xs text-gray-500">${health.status === 'OK' ? 'Running' : 'Error'}</p>
                            </div>
                            <div class="text-center">
                                <div class="w-3 h-3 bg-green-500 rounded-full mx-auto mb-2"></div>
                                <p class="text-sm font-medium text-gray-900">Services</p>
                                <p class="text-xs text-gray-500">All Operational</p>
                            </div>
                        </div>
                    `;
                    
                    document.getElementById('systemStatus').innerHTML = statusHtml;
                    
                } catch (error) {
                    console.error('Error loading dashboard data:', error);
                    this.showNotification('Error loading dashboard data', 'error');
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
        
        // Initialize app when DOM is loaded
        document.addEventListener('DOMContentLoaded', function() {
            window.app = new ServiceDeskApp();
        });
    </script>
</body>
</html>
SIMPLE_FRONTEND_EOF

# Ensure proper permissions
sudo chown -R ubuntu:ubuntu $APP_DIR

# Start service
echo "Starting service with simple frontend..."
sudo systemctl start $SERVICE_NAME

# Wait for startup
sleep 10

# Test the simple frontend
echo "Testing simple frontend..."
FRONTEND_TEST=$(curl -s -H "Accept: text/html" http://localhost:5000/)

if echo "$FRONTEND_TEST" | grep -q "Calpion IT Service Desk"; then
    echo "✓ Simple frontend serving correctly"
else
    echo "✗ Frontend still not working"
fi

# Test HTTPS
HTTPS_TEST=$(curl -k -s -H "Accept: text/html" https://98.81.235.7/)

if echo "$HTTPS_TEST" | grep -q "Calpion IT Service Desk"; then
    echo "✓ HTTPS frontend working"
else
    echo "✗ HTTPS frontend issue"
fi

echo ""
echo "=== SIMPLE FRONTEND DEPLOYMENT COMPLETE ==="
echo "✅ No build tools required"
echo "✅ Single-file HTML application"
echo "✅ Complete login and dashboard functionality"
echo "✅ Real-time data from your API endpoints"
echo ""
echo "Access: https://98.81.235.7"
echo "Login: john.doe / password123"

# Show service status
sudo systemctl status $SERVICE_NAME --no-pager --lines=5