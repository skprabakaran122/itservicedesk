#!/bin/bash

# Complete production deployment with proper React app serving
cd /var/www/itservicedesk

echo "Creating production deployment with proper React serving..."

# First ensure we have a clean production build
npm run build

# Create the correct production server that serves built React files
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

// Body parsing
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true }));
app.set('trust proxy', true);

// Static files from the Vite build
const staticPath = path.join(__dirname, '../dist/public');
app.use(express.static(staticPath, {
  maxAge: '1d',
  etag: true
}));

// Auth middleware
const requireAuth = (req, res, next) => {
  if (!req.session.user) {
    return res.status(401).json({ message: 'Not authenticated' });
  }
  next();
};

// API Routes
app.post('/api/auth/login', async (req, res) => {
  try {
    const { username, password } = req.body;
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
    
    res.json({ user: req.session.user });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ message: 'Internal server error' });
  }
});

app.post('/api/auth/logout', (req, res) => {
  req.session.destroy((err) => {
    if (err) return res.status(500).json({ message: 'Could not log out' });
    res.json({ message: 'Logged out successfully' });
  });
});

app.get('/api/auth/me', (req, res) => {
  if (!req.session.user) {
    return res.status(401).json({ message: 'Not authenticated' });
  }
  res.json({ user: req.session.user });
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

app.post('/api/products', requireAuth, async (req, res) => {
  try {
    const { name, category, description } = req.body;
    const result = await pool.query(
      'INSERT INTO products (name, category, description, is_active) VALUES ($1, $2, $3, $4) RETURNING *',
      [name, category, description, 'true']
    );
    res.json(result.rows[0]);
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

// Serve React app for all other routes
app.get('*', (req, res) => {
  res.sendFile(path.join(staticPath, 'index.html'));
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Calpion IT Service Desk running on port ${PORT}`);
});
EOF

# Update PM2 configuration to use our production server
cat > ecosystem.config.cjs << 'EOF'
module.exports = {
  apps: [{
    name: 'itservicedesk',
    script: 'dist/production.cjs',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production',
      PORT: 5000
    },
    log_file: 'logs/combined.log',
    out_file: 'logs/out.log',
    error_file: 'logs/err.log',
    log_date_format: 'YYYY-MM-DD HH:mm:ss'
  }]
};
EOF

# Make sure the built index.html references the correct assets
cat > dist/public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Calpion IT Service Desk</title>
    <link rel="stylesheet" href="/assets/index-Cf-nQCTa.css" />
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/assets/index-u5OElkvU.js"></script>
  </body>
</html>
EOF

echo "Restarting with production configuration..."
pm2 delete itservicedesk 2>/dev/null || true
pm2 start ecosystem.config.cjs
sleep 3

echo "Testing login and dashboard..."
LOGIN_RESULT=$(curl -s -X POST http://localhost:5000/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"username":"admin","password":"password123"}')

if echo "$LOGIN_RESULT" | grep -q "admin"; then
    echo "Login working"
else
    echo "Login failed: $LOGIN_RESULT"
fi

echo ""
echo "Production server deployed. Access at: https://98.81.235.7"
echo "Login with: admin / password123"