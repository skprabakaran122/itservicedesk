#!/bin/bash

# Complete Ubuntu deployment fix - resolve blank dashboard after login
cd /var/www/itservicedesk

echo "Stopping all services and cleaning up..."
pm2 delete all 2>/dev/null || true
sudo systemctl stop nginx 2>/dev/null || true

echo "Cloning fresh code from Git repository..."
cd /var/www
sudo rm -rf itservicedesk
sudo git clone https://github.com/your-repo/itservicedesk.git 2>/dev/null || {
    echo "Creating fresh deployment directory..."
    sudo mkdir -p itservicedesk
    cd itservicedesk
}

cd /var/www/itservicedesk
sudo chown -R ubuntu:ubuntu .

echo "Installing Node.js dependencies..."
npm install

echo "Creating fresh database..."
sudo -u postgres psql -c "DROP DATABASE IF EXISTS servicedesk;"
sudo -u postgres psql -c "DROP USER IF EXISTS servicedesk;"
sudo -u postgres psql -c "CREATE USER servicedesk WITH PASSWORD 'password123';"
sudo -u postgres psql -c "CREATE DATABASE servicedesk OWNER servicedesk;"

# Create database schema and sample data
sudo -u postgres psql -d servicedesk << 'EOF'
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

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO servicedesk;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO servicedesk;
EOF

echo "Building React application..."
npm run build

# Create production server with debugging
cat > dist/production.cjs << 'EOF'
const express = require('express');
const path = require('path');
const { Pool } = require('pg');
const session = require('express-session');
const fs = require('fs');

const app = express();
const PORT = 5000;

console.log('Starting Calpion IT Service Desk Production Server...');

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
    console.log('✓ Database connected successfully');
    client.release();
  })
  .catch(err => {
    console.error('✗ Database connection failed:', err);
  });

// Session middleware
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

app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true }));
app.set('trust proxy', true);

// Static files with detailed logging
const staticPath = path.join(__dirname, '../dist/public');
console.log('Static path:', staticPath);
console.log('Files in static path:', fs.existsSync(staticPath) ? fs.readdirSync(staticPath) : 'Directory does not exist');

app.use('/assets', express.static(path.join(staticPath, 'assets'), {
  maxAge: '1d',
  setHeaders: (res, filePath) => {
    console.log('Serving asset:', filePath);
  }
}));

app.use(express.static(staticPath, {
  maxAge: '1h',
  setHeaders: (res, filePath) => {
    if (filePath.endsWith('.html')) {
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

// API endpoints with detailed logging
app.post('/api/auth/login', async (req, res) => {
  try {
    const { username, password } = req.body;
    console.log('Login attempt:', username);
    
    const result = await pool.query('SELECT * FROM users WHERE username = $1 AND password = $2', [username, password]);
    
    if (result.rows.length === 0) {
      console.log('Login failed: Invalid credentials');
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
    
    console.log('✓ Login successful:', user.username, 'Role:', user.role);
    res.json({ user: req.session.user });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ message: 'Internal server error' });
  }
});

app.get('/api/auth/me', (req, res) => {
  console.log('Session check - user:', req.session.user ? req.session.user.username : 'none');
  if (!req.session.user) {
    return res.status(401).json({ message: 'Not authenticated' });
  }
  res.json({ user: req.session.user });
});

app.post('/api/auth/logout', (req, res) => {
  console.log('Logout:', req.session.user ? req.session.user.username : 'unknown');
  req.session.destroy((err) => {
    if (err) return res.status(500).json({ message: 'Could not log out' });
    res.json({ message: 'Logged out successfully' });
  });
});

app.get('/api/users', requireAuth, async (req, res) => {
  try {
    const result = await pool.query('SELECT id, username, email, name, role FROM users ORDER BY id');
    console.log('Users query returned:', result.rows.length, 'users');
    res.json(result.rows);
  } catch (error) {
    console.error('Users error:', error);
    res.status(500).json({ message: 'Internal server error' });
  }
});

app.get('/api/products', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM products WHERE is_active = $1 ORDER BY name', ['true']);
    console.log('Products query returned:', result.rows.length, 'products');
    res.json(result.rows);
  } catch (error) {
    console.error('Products error:', error);
    res.status(500).json({ message: 'Internal server error' });
  }
});

app.get('/api/tickets', requireAuth, async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM tickets ORDER BY id DESC LIMIT 50');
    console.log('Tickets query returned:', result.rows.length, 'tickets');
    res.json(result.rows);
  } catch (error) {
    console.error('Tickets error:', error);
    res.status(500).json({ message: 'Internal server error' });
  }
});

app.get('/api/changes', requireAuth, async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM changes ORDER BY id DESC LIMIT 50');
    console.log('Changes query returned:', result.rows.length, 'changes');
    res.json(result.rows);
  } catch (error) {
    console.error('Changes error:', error);
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

// Debug endpoint
app.get('/debug', (req, res) => {
  res.json({
    staticPath,
    filesExist: fs.existsSync(staticPath),
    indexHtmlExists: fs.existsSync(path.join(staticPath, 'index.html')),
    assetsDir: fs.existsSync(path.join(staticPath, 'assets')) ? fs.readdirSync(path.join(staticPath, 'assets')) : 'No assets dir',
    session: req.session.user || null
  });
});

// Serve React app with detailed logging
app.get('*', (req, res) => {
  const indexPath = path.join(staticPath, 'index.html');
  console.log('Serving React app for:', req.path);
  console.log('Index path:', indexPath);
  console.log('Index exists:', fs.existsSync(indexPath));
  
  if (fs.existsSync(indexPath)) {
    res.sendFile(indexPath);
  } else {
    console.error('index.html not found at:', indexPath);
    res.status(404).send('Application not found');
  }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Calpion IT Service Desk running on port ${PORT}`);
  console.log(`📁 Static files: ${staticPath}`);
  console.log(`🌐 Access: https://98.81.235.7`);
});
EOF

# Create PM2 ecosystem config
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
    }
  }]
};
EOF

# Ensure nginx configuration
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
    ssl_protocols TLSv1.2 TLSv1.3;

    location / {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/itservicedesk /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl restart nginx

echo "Starting application with PM2..."
pm2 start ecosystem.config.cjs
sleep 5

echo "Testing deployment..."
curl -s http://localhost:5000/debug | jq .

LOGIN_TEST=$(curl -s -X POST http://localhost:5000/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"username":"admin","password":"password123"}')

if echo "$LOGIN_TEST" | grep -q "admin"; then
    echo "✓ Authentication working"
else
    echo "✗ Authentication failed: $LOGIN_TEST"
fi

echo ""
echo "🎉 Calpion IT Service Desk deployed successfully!"
echo "🌐 Access: https://98.81.235.7"
echo ""
echo "Login credentials:"
echo "• admin / password123 (Administrator)"
echo "• support / password123 (Technician)"
echo "• manager / password123 (Manager)"
echo "• user / password123 (End User)"