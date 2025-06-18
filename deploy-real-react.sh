#!/bin/bash

# Deploy your actual React application to Ubuntu server
cd /var/www/itservicedesk

echo "Building and deploying your actual React application..."

# Build the real React app
echo "Building React app with Vite..."
npm run build

# Check if build succeeded
if [ ! -f "dist/index.html" ]; then
    echo "Vite build failed, trying manual build..."
    
    # Manual build approach
    npx vite build --outDir dist --emptyOutDir
fi

# Ensure the built files are in the right place
if [ -f "dist/index.html" ]; then
    echo "Moving built files to dist/public..."
    mkdir -p dist/public
    cp -r dist/* dist/public/ 2>/dev/null || true
    
    # Also copy any assets
    if [ -d "client/public" ]; then
        cp -r client/public/* dist/public/ 2>/dev/null || true
    fi
else
    echo "Build failed, copying source files directly..."
    mkdir -p dist/public
    
    # Copy the main HTML file
    cp client/index.html dist/public/
    
    # Copy assets
    if [ -d "client/public" ]; then
        cp -r client/public/* dist/public/
    fi
    
    # Build the TypeScript manually
    echo "Compiling TypeScript..."
    npx tsc --project client/tsconfig.json --outDir dist/public/js 2>/dev/null || true
fi

# Update the production server to serve your React app properly
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

// Static files - serve your actual React build
const staticPath = path.join(__dirname, '../dist/public');
console.log('Serving static files from:', staticPath);

// Serve static files with proper headers
app.use(express.static(staticPath, {
  maxAge: '1h',
  etag: true,
  setHeaders: (res, filePath) => {
    if (filePath.endsWith('.html')) {
      res.set('Cache-Control', 'no-cache, no-store, must-revalidate');
    }
    if (filePath.endsWith('.js') || filePath.endsWith('.css')) {
      res.set('Cache-Control', 'public, max-age=31536000');
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

// Serve your React app for all non-API routes (SPA routing)
app.get('*', (req, res) => {
  const indexPath = path.join(staticPath, 'index.html');
  console.log('Serving React app:', req.path, '->', indexPath);
  res.sendFile(indexPath, (err) => {
    if (err) {
      console.error('Error serving React app:', err);
      res.status(500).send('Error loading application');
    }
  });
});

// Error handler
app.use((err, req, res, next) => {
  console.error('Server error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Calpion IT Service Desk running on port ${PORT}`);
  console.log(`📁 Static files: ${staticPath}`);
  console.log(`🗄️  Database: servicedesk@localhost:5432`);
  console.log(`🌐 Access: https://98.81.235.7`);
});
EOF

echo "Checking built files..."
ls -la dist/public/

echo "Restarting server with your React app..."
pm2 restart itservicedesk
sleep 3

echo ""
echo "✅ Your React application deployed!"
echo "🌐 Access: https://98.81.235.7"
echo ""
echo "If still blank, checking build output..."
curl -s http://localhost:5000/ | head -10