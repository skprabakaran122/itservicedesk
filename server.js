const express = require('express');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true }));

// Trust proxy for nginx
app.set('trust proxy', true);

// Serve static files - check both dist/public and client/dist
let staticPath;
if (fs.existsSync(path.join(__dirname, 'dist', 'public'))) {
  staticPath = path.join(__dirname, 'dist', 'public');
} else if (fs.existsSync(path.join(__dirname, 'client', 'dist'))) {
  staticPath = path.join(__dirname, 'client', 'dist');
} else {
  // Fallback to serving the development client directly
  staticPath = path.join(__dirname, 'client');
}

console.log(`Serving static files from: ${staticPath}`);
app.use(express.static(staticPath));

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV || 'development',
    staticPath: staticPath
  });
});

// Simple API mock for immediate functionality
const users = [
  { id: 1, username: 'test.admin', password: 'password123', email: 'admin@calpion.com', role: 'admin', department: 'IT' },
  { id: 2, username: 'test.user', password: 'password123', email: 'user@calpion.com', role: 'user', department: 'Operations' },
  { id: 3, username: 'john.doe', password: 'password123', email: 'john.doe@calpion.com', role: 'agent', department: 'Support' }
];

const tickets = [
  { id: 1, title: 'System Login Issue', description: 'Cannot access system', status: 'open', priority: 'high', createdAt: new Date(), userId: 2 },
  { id: 2, title: 'Network Connectivity', description: 'Slow internet connection', status: 'in-progress', priority: 'medium', createdAt: new Date(), userId: 2 },
  { id: 3, title: 'Software Installation', description: 'Need new software installed', status: 'resolved', priority: 'low', createdAt: new Date(), userId: 2 }
];

// Session storage
const sessions = new Map();

// Authentication API
app.post('/api/auth/login', (req, res) => {
  const { username, password } = req.body;
  const user = users.find(u => u.username === username && u.password === password);
  
  if (user) {
    const sessionId = Math.random().toString(36).substring(7);
    sessions.set(sessionId, user);
    res.cookie('sessionId', sessionId, { httpOnly: true });
    res.json({ ...user, password: undefined });
  } else {
    res.status(401).json({ message: 'Invalid credentials' });
  }
});

app.get('/api/auth/me', (req, res) => {
  const sessionId = req.headers.cookie?.split('sessionId=')[1]?.split(';')[0];
  const user = sessions.get(sessionId);
  
  if (user) {
    res.json({ ...user, password: undefined });
  } else {
    res.status(401).json({ message: 'Not authenticated' });
  }
});

app.post('/api/auth/logout', (req, res) => {
  const sessionId = req.headers.cookie?.split('sessionId=')[1]?.split(';')[0];
  sessions.delete(sessionId);
  res.json({ message: 'Logged out' });
});

// Basic API endpoints
app.get('/api/tickets', (req, res) => {
  res.json(tickets);
});

app.get('/api/users', (req, res) => {
  res.json(users.map(u => ({ ...u, password: undefined })));
});

// Dashboard stats
app.get('/api/dashboard/stats', (req, res) => {
  res.json({
    totalTickets: tickets.length,
    openTickets: tickets.filter(t => t.status === 'open').length,
    resolvedTickets: tickets.filter(t => t.status === 'resolved').length,
    totalUsers: users.length
  });
});

// Serve React app for all other routes
app.get('*', (req, res) => {
  const indexPath = path.join(staticPath, 'index.html');
  if (fs.existsSync(indexPath)) {
    res.sendFile(indexPath);
  } else {
    // Fallback HTML for development
    res.send(`
      <!DOCTYPE html>
      <html>
        <head>
          <title>IT Service Desk - Calpion</title>
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <style>
            body { font-family: system-ui, sans-serif; margin: 40px; text-align: center; }
            .logo { color: #2563eb; font-size: 2rem; font-weight: bold; margin-bottom: 20px; }
            .status { background: #10b981; color: white; padding: 10px 20px; border-radius: 8px; display: inline-block; }
          </style>
        </head>
        <body>
          <div class="logo">Calpion IT Service Desk</div>
          <div class="status">✓ Production Server Running</div>
          <p>Environment: ${process.env.NODE_ENV || 'development'}</p>
          <p>Port: ${PORT}</p>
          <p>Static Path: ${staticPath}</p>
          <p><a href="/health">Health Check</a></p>
        </body>
      </html>
    `);
  }
});

// Error handling
app.use((err, req, res, next) => {
  console.error('Server error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Production server running on port ${PORT}`);
  console.log(`Serving static files from: ${staticPath}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`Application ready at http://localhost:${PORT}`);
});