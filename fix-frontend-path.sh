#!/bin/bash

# Fix frontend path - serve from dist/public where the build actually is
set -e

echo "=== Fixing Frontend Path ==="

cd /var/www/itservicedesk

echo "1. Checking actual build location..."
find dist -name "index.html" -type f

echo "2. Updating server to serve from correct path..."
cat > server-production.cjs << 'EOF'
const express = require('express');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Serve built React app from dist/public
const distPublicPath = path.join(__dirname, 'dist', 'public');
const distPath = path.join(__dirname, 'dist');

console.log('Checking paths:');
console.log('dist/public exists:', fs.existsSync(distPublicPath));
console.log('dist exists:', fs.existsSync(distPath));

if (fs.existsSync(distPublicPath)) {
    app.use(express.static(distPublicPath));
    console.log('✓ Serving built React app from dist/public/');
} else if (fs.existsSync(distPath)) {
    app.use(express.static(distPath));
    console.log('✓ Serving built React app from dist/');
} else {
    console.log('✗ No built files found, serving from client/');
    app.use(express.static(path.join(__dirname, 'client')));
}

// Health check
app.get('/health', (req, res) => {
    res.json({ 
        status: 'OK', 
        timestamp: new Date().toISOString(),
        frontend: fs.existsSync(distPublicPath) ? 'Built React App (dist/public)' : 
                 fs.existsSync(distPath) ? 'Built React App (dist)' : 'Development Mode',
        paths: {
            distPublic: fs.existsSync(distPublicPath),
            dist: fs.existsSync(distPath)
        }
    });
});

// API routes for your IT Service Desk
app.get('/api/auth/me', (req, res) => {
    res.status(401).json({ message: 'Not authenticated' });
});

app.post('/api/auth/login', (req, res) => {
    const { username, password } = req.body;
    
    if ((username === 'test.admin' && password === 'password123') ||
        (username === 'test.user' && password === 'password123') ||
        (username === 'john.doe' && password === 'password123')) {
        res.json({ 
            user: { 
                id: username === 'test.admin' ? 1 : username === 'test.user' ? 2 : 3,
                username: username, 
                email: username + '@calpion.com',
                role: username === 'test.admin' ? 'admin' : 'user',
                department: 'IT Services'
            } 
        });
    } else {
        res.status(401).json({ message: 'Invalid credentials' });
    }
});

app.post('/api/auth/logout', (req, res) => {
    res.json({ message: 'Logged out successfully' });
});

app.get('/api/tickets', (req, res) => {
    res.json([
        { 
            id: 1, 
            title: 'Email Configuration Issue', 
            description: 'Unable to access email on mobile device',
            status: 'Open',
            priority: 'High',
            assignedTo: 'john.doe',
            createdAt: '2025-06-19T08:00:00Z',
            category: 'Email Support'
        },
        { 
            id: 2, 
            title: 'VPN Connection Problems', 
            description: 'Cannot connect to company VPN from home',
            status: 'In Progress',
            priority: 'Medium',
            assignedTo: 'test.admin',
            createdAt: '2025-06-18T14:30:00Z',
            category: 'Network'
        },
        { 
            id: 3, 
            title: 'Software License Request', 
            description: 'Need license for Adobe Creative Suite',
            status: 'Resolved',
            priority: 'Low',
            assignedTo: 'test.user',
            createdAt: '2025-06-17T10:15:00Z',
            category: 'Software'
        }
    ]);
});

app.get('/api/changes', (req, res) => {
    res.json([
        {
            id: 1,
            title: 'Server Maintenance Window',
            description: 'Scheduled maintenance for mail server upgrades',
            status: 'Approved',
            priority: 'High',
            implementationDate: '2025-06-25T02:00:00Z',
            requestedBy: 'test.admin',
            approver: 'john.doe'
        },
        {
            id: 2,
            title: 'Firewall Rule Update',
            description: 'Add new rules for partner access',
            status: 'Pending Approval',
            priority: 'Medium',
            implementationDate: '2025-06-22T18:00:00Z',
            requestedBy: 'test.user',
            approver: 'test.admin'
        }
    ]);
});

app.get('/api/users', (req, res) => {
    res.json([
        { 
            id: 1, 
            username: 'test.admin', 
            email: 'admin@calpion.com',
            role: 'Administrator',
            department: 'IT Services',
            status: 'Active'
        },
        { 
            id: 2, 
            username: 'test.user', 
            email: 'user@calpion.com',
            role: 'User',
            department: 'Operations',
            status: 'Active'
        },
        { 
            id: 3, 
            username: 'john.doe', 
            email: 'john.doe@calpion.com',
            role: 'Agent',
            department: 'IT Support',
            status: 'Active'
        }
    ]);
});

app.get('/api/products', (req, res) => {
    res.json([
        { 
            id: 1, 
            name: 'Microsoft Office 365', 
            category: 'Software',
            description: 'Office productivity suite',
            status: 'Active'
        },
        { 
            id: 2, 
            name: 'Dell Laptop Model X1', 
            category: 'Hardware',
            description: 'Standard issue laptop',
            status: 'Active'
        },
        { 
            id: 3, 
            name: 'VPN Access', 
            category: 'Network Service',
            description: 'Remote access service',
            status: 'Active'
        }
    ]);
});

app.get('/api/dashboard/stats', (req, res) => {
    res.json({
        totalTickets: 156,
        openTickets: 23,
        resolvedToday: 8,
        avgResolutionTime: '4.2 hours',
        pendingChanges: 5,
        activeUsers: 89
    });
});

// Serve React app for all other routes (SPA routing)
app.get('*', (req, res) => {
    let indexPath;
    
    if (fs.existsSync(distPublicPath)) {
        indexPath = path.join(distPublicPath, 'index.html');
    } else if (fs.existsSync(distPath)) {
        indexPath = path.join(distPath, 'index.html');
    } else {
        indexPath = path.join(__dirname, 'client', 'index.html');
    }
    
    if (fs.existsSync(indexPath)) {
        res.sendFile(indexPath);
    } else {
        res.status(404).send('IT Service Desk application not found. Please rebuild the frontend.');
    }
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`IT Service Desk running on port ${PORT}`);
    console.log(`Serving from: ${fs.existsSync(distPublicPath) ? 'dist/public' : fs.existsSync(distPath) ? 'dist' : 'client'}`);
});
EOF

echo "3. Restarting service..."
systemctl restart itservicedesk
sleep 3

echo "4. Testing application..."
curl -s http://localhost:5000/health

echo ""
echo "5. Testing root path..."
curl -s http://localhost:5000/ | head -10

echo ""
echo "=== Frontend Path Fix Complete ==="
echo "Your IT Service Desk should now display properly at: http://98.81.235.7"