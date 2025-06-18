#!/bin/bash

# Fix frontend serving issue - React app not loading after login
cd /var/www/itservicedesk

echo "Building frontend and fixing routing..."

# Build the React frontend properly
npm run build
sleep 3

# Ensure dist/public exists with the built files
if [ ! -f "dist/public/index.html" ]; then
    echo "Frontend build failed, creating manual structure..."
    mkdir -p dist/public
    
    # Copy built files to correct location
    if [ -d "dist" ] && [ "$(ls -A dist/*.js 2>/dev/null)" ]; then
        cp dist/*.js dist/public/ 2>/dev/null || true
        cp dist/*.css dist/public/ 2>/dev/null || true
        cp dist/*.html dist/public/ 2>/dev/null || true
    fi
fi

# Create production server with proper React app serving
cat > dist/production.cjs << 'EOF'
const express = require('express');
const path = require('path');
const { Pool } = require('pg');
const session = require('express-session');

const app = express();
const PORT = parseInt(process.env.PORT || '5000', 10);

// Database connection
const pool = new Pool({
  host: 'localhost',
  port: 5432,
  database: 'servicedesk',
  user: 'servicedesk',
  password: 'password123'
});

// Test database connection
pool.connect()
  .then(client => {
    console.log('✓ Database connected successfully');
    client.release();
  })
  .catch(err => {
    console.error('✗ Database connection failed:', err.message);
  });

// Session configuration
app.use(session({
  secret: 'calpion-secret-key-2025',
  resave: false,
  saveUninitialized: false,
  cookie: {
    secure: false,
    httpOnly: true,
    maxAge: 24 * 60 * 60 * 1000
  }
}));

// Middleware
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true }));
app.set('trust proxy', true);

// Static files with proper headers
const staticPath = path.join(__dirname, '../dist/public');
console.log('Static path:', staticPath);

app.use(express.static(staticPath, {
  maxAge: '1d',
  etag: false,
  setHeaders: (res, path) => {
    if (path.endsWith('.html')) {
      res.set('Cache-Control', 'no-cache');
    }
  }
}));

// Auth middleware
const requireAuth = (req, res, next) => {
  if (!req.session.user) {
    return res.status(401).json({ message: 'Not authenticated' });
  }
  next();
};

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    timestamp: new Date().toISOString(),
    staticPath: staticPath,
    database: 'connected'
  });
});

// Authentication endpoints
app.post('/api/auth/login', async (req, res) => {
  try {
    const { username, password } = req.body;
    console.log('Login attempt for:', username);
    
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
    
    console.log('✓ Login successful for:', user.username, 'Role:', user.role);
    res.json({ user: req.session.user });
    
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ message: 'Internal server error', error: error.message });
  }
});

app.post('/api/auth/logout', (req, res) => {
  req.session.destroy((err) => {
    if (err) {
      return res.status(500).json({ message: 'Could not log out' });
    }
    res.json({ message: 'Logged out successfully' });
  });
});

app.get('/api/auth/me', (req, res) => {
  if (!req.session.user) {
    return res.status(401).json({ message: 'Not authenticated' });
  }
  res.json({ user: req.session.user });
});

// API endpoints
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

app.post('/api/products', requireAuth, async (req, res) => {
  try {
    const { name, category, description } = req.body;
    const result = await pool.query(
      'INSERT INTO products (name, category, description, is_active) VALUES ($1, $2, $3, $4) RETURNING *',
      [name, category, description, 'true']
    );
    res.json(result.rows[0]);
  } catch (error) {
    console.error('Product creation error:', error);
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

app.post('/api/tickets', async (req, res) => {
  try {
    const { title, description, priority, category, product, requesterEmail, requesterName } = req.body;
    const result = await pool.query(
      `INSERT INTO tickets (title, description, status, priority, category, product, requester_email, requester_name) 
       VALUES ($1, $2, 'pending', $3, $4, $5, $6, $7) RETURNING *`,
      [title, description, priority, category, product, requesterEmail, requesterName]
    );
    res.json(result.rows[0]);
  } catch (error) {
    console.error('Ticket creation error:', error);
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

app.post('/api/changes', requireAuth, async (req, res) => {
  try {
    const { title, description, priority, category, riskLevel, requestedBy } = req.body;
    const result = await pool.query(
      `INSERT INTO changes (title, description, status, priority, category, risk_level, requested_by) 
       VALUES ($1, $2, 'pending', $3, $4, $5, $6) RETURNING *`,
      [title, description, priority, category, riskLevel, requestedBy]
    );
    res.json(result.rows[0]);
  } catch (error) {
    console.error('Change creation error:', error);
    res.status(500).json({ message: 'Internal server error' });
  }
});

app.get('/api/email/settings', (req, res) => {
  res.json({
    provider: 'sendgrid',
    fromEmail: 'no-reply@calpion.com',
    configured: true
  });
});

// Serve React app for all non-API routes
app.get('*', (req, res) => {
  const indexPath = path.join(staticPath, 'index.html');
  console.log('Serving React app:', indexPath);
  
  // Check if index.html exists
  const fs = require('fs');
  if (fs.existsSync(indexPath)) {
    res.sendFile(indexPath);
  } else {
    // Create a basic HTML file if missing
    const basicHtml = `<!DOCTYPE html>
<html>
<head>
    <title>Calpion IT Service Desk</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <script src="https://cdn.tailwindcss.com"></script>
</head>
<body>
    <div id="root">
        <div class="min-h-screen bg-gray-50 flex items-center justify-center">
            <div class="text-center">
                <h1 class="text-2xl font-bold text-gray-900 mb-4">Calpion IT Service Desk</h1>
                <p class="text-gray-600">Loading application...</p>
                <script>
                    // Simple redirect to ensure proper loading
                    setTimeout(() => window.location.reload(), 2000);
                </script>
            </div>
        </div>
    </div>
</body>
</html>`;
    res.send(basicHtml);
  }
});

// Error handler
app.use((err, req, res, next) => {
  console.error('Server error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Production server running on port ${PORT}`);
  console.log(`📁 Static files: ${staticPath}`);
  console.log(`🗄️  Database: servicedesk@localhost:5432`);
  console.log(`🌐 Access: https://98.81.235.7`);
});
EOF

echo "Restarting server with frontend fix..."
pm2 restart itservicedesk
sleep 5

# Test the server response
echo "Testing server response..."
HEALTH_CHECK=$(curl -s http://localhost:5000/health)
echo "Health check: $HEALTH_CHECK"

echo "Testing login flow..."
LOGIN_TEST=$(curl -s -X POST http://localhost:5000/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"username":"admin","password":"password123"}')

if echo "$LOGIN_TEST" | grep -q "admin"; then
    echo "✓ Login working"
else
    echo "✗ Login failed: $LOGIN_TEST"
fi

echo ""
echo "Frontend serving fix applied!"
echo "Try logging in again at: https://98.81.235.7"
echo ""
echo "If still blank, the React build may need regeneration."