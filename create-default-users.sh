#!/bin/bash

# Create fresh database with complete schema and sample data
cd /var/www/itservicedesk

echo "Creating fresh database..."

# Drop existing database completely
sudo -u postgres psql -c "DROP DATABASE IF EXISTS servicedesk;"
sudo -u postgres psql -c "DROP USER IF EXISTS servicedesk;"

# Create new database and user
sudo -u postgres psql -c "CREATE USER servicedesk WITH PASSWORD 'password123';"
sudo -u postgres psql -c "CREATE DATABASE servicedesk OWNER servicedesk;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE servicedesk TO servicedesk;"

# Create complete schema using SQL
sudo -u postgres psql -d servicedesk << 'EOF'
-- Users table
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

-- Products table
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    category VARCHAR(50) NOT NULL,
    description TEXT,
    is_active VARCHAR(10) NOT NULL DEFAULT 'true',
    created_at TIMESTAMP DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP DEFAULT NOW() NOT NULL
);

-- Tickets table
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

-- Changes table
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

-- Settings table
CREATE TABLE settings (
    id SERIAL PRIMARY KEY,
    key VARCHAR(100) NOT NULL UNIQUE,
    value TEXT,
    description TEXT,
    created_at TIMESTAMP DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP DEFAULT NOW() NOT NULL
);

-- Sessions table
CREATE TABLE sessions (
    sid VARCHAR PRIMARY KEY,
    sess JSONB NOT NULL,
    expire TIMESTAMP NOT NULL
);

CREATE INDEX IDX_session_expire ON sessions(expire);

-- Insert default users
INSERT INTO users (username, email, password, role, name) VALUES
('admin', 'admin@calpion.com', 'password123', 'admin', 'System Administrator'),
('support', 'support@calpion.com', 'password123', 'technician', 'Support Technician'),
('manager', 'manager@calpion.com', 'password123', 'manager', 'IT Manager'),
('user', 'user@calpion.com', 'password123', 'user', 'End User');

-- Insert sample products
INSERT INTO products (name, category, description, is_active) VALUES
('Microsoft Office 365', 'Software', 'Office productivity suite', 'true'),
('Windows 10', 'Operating System', 'Desktop operating system', 'true'),
('VPN Access', 'Network', 'Remote access solution', 'true'),
('Printer Access', 'Hardware', 'Network printer configuration', 'true'),
('Email Setup', 'Communication', 'Email account configuration', 'true');

-- Insert sample tickets
INSERT INTO tickets (title, description, status, priority, category, product, requester_email, requester_name, created_at) VALUES
('Cannot access email', 'Unable to login to Outlook', 'open', 'medium', 'software', 'Microsoft Office 365', 'john@calpion.com', 'John Smith', NOW() - INTERVAL '2 hours'),
('Printer not working', 'Printer showing offline status', 'pending', 'low', 'hardware', 'Printer Access', 'jane@calpion.com', 'Jane Doe', NOW() - INTERVAL '1 day'),
('VPN connection issues', 'Cannot connect to company VPN', 'in-progress', 'high', 'network', 'VPN Access', 'bob@calpion.com', 'Bob Johnson', NOW() - INTERVAL '3 hours');

-- Insert sample changes
INSERT INTO changes (title, description, status, priority, category, risk_level, requested_by, created_at) VALUES
('Update antivirus software', 'Deploy latest antivirus definitions', 'pending', 'medium', 'system', 'low', 'admin', NOW() - INTERVAL '1 day'),
('Network firewall update', 'Apply security patches to firewall', 'approved', 'high', 'infrastructure', 'medium', 'manager', NOW() - INTERVAL '2 days');

-- Insert email settings
INSERT INTO settings (key, value, description) VALUES
('email_provider', 'sendgrid', 'Email service provider'),
('email_from', 'no-reply@calpion.com', 'Default from email address'),
('email_configured', 'true', 'Email service configuration status');

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO servicedesk;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO servicedesk;
EOF

echo "Database created successfully with sample data"

# Create production server with database connection
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

// Test connection
pool.connect()
  .then(client => {
    console.log('Database connected successfully');
    client.release();
  })
  .catch(err => {
    console.error('Database connection failed:', err);
  });

// Session configuration
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

// Middleware
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true }));
app.set('trust proxy', true);

// Static files
const staticPath = path.join(__dirname, '../dist/public');
app.use(express.static(staticPath));

// Auth middleware
const requireAuth = (req, res, next) => {
  if (!req.session.user) {
    return res.status(401).json({ message: 'Not authenticated' });
  }
  next();
};

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
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
    
    console.log('Login successful for:', user.username);
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

// React app
app.get('*', (req, res) => {
  res.sendFile(path.join(staticPath, 'index.html'));
});

// Error handler
app.use((err, req, res, next) => {
  console.error('Server error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Production server running on port ${PORT}`);
  console.log(`Static files: ${staticPath}`);
  console.log(`Database: servicedesk@localhost:5432/servicedesk`);
});
EOF

echo "Restarting application with fresh database..."
pm2 restart itservicedesk
sleep 5

# Test authentication with fresh database
echo "Testing authentication with fresh database..."
for user in "admin" "support" "manager" "user"; do
    AUTH_TEST=$(curl -s -X POST http://localhost:5000/api/auth/login \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"$user\",\"password\":\"password123\"}")
    
    if echo "$AUTH_TEST" | grep -q "$user"; then
        echo "✓ SUCCESS: $user / password123"
    else
        echo "✗ FAILED: $user - $(echo "$AUTH_TEST" | head -c 100)"
    fi
done

echo ""
echo "Fresh database created successfully!"
echo "Access your IT Service Desk at: https://98.81.235.7"
echo ""
echo "Login credentials:"
echo "• admin / password123 (Administrator)"
echo "• support / password123 (Technician)"
echo "• manager / password123 (Manager)"
echo "• user / password123 (End User)"
echo ""
echo "Sample data included:"
echo "• 5 products (Office 365, Windows 10, VPN, Printer, Email)"
echo "• 3 tickets (Email, Printer, VPN issues)"
echo "• 2 change requests (Antivirus, Firewall updates)"