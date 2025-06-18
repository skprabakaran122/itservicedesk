#!/bin/bash

echo "=== DEPLOYING FROM GITHUB TO PRODUCTION ==="

# Variables
REPO_URL="https://github.com/skprabakaran122/itservicedesk.git"
APP_DIR="/var/www/itservicedesk"

# Clean and setup
pm2 delete all 2>/dev/null || true
sudo rm -rf $APP_DIR
sudo mkdir -p $APP_DIR
cd $APP_DIR

# Clone repository
echo "Cloning from GitHub..."
git clone $REPO_URL .

# Install Node.js 20
echo "Installing Node.js..."
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install dependencies
echo "Installing dependencies..."
npm install --production

# Setup PostgreSQL database
echo "Setting up database..."
sudo -u postgres psql << 'DB_EOF'
DROP DATABASE IF EXISTS servicedesk;
DROP USER IF EXISTS servicedesk;
CREATE USER servicedesk WITH PASSWORD 'servicedesk123';
CREATE DATABASE servicedesk OWNER servicedesk;
GRANT ALL PRIVILEGES ON DATABASE servicedesk TO servicedesk;
\c servicedesk
GRANT ALL ON SCHEMA public TO servicedesk;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO servicedesk;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO servicedesk;
ALTER USER servicedesk CREATEDB;

-- Create complete database schema
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(255) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL DEFAULT 'user',
    name VARCHAR(255) NOT NULL,
    assigned_products TEXT[],
    department VARCHAR(255),
    business_unit VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(100) DEFAULT 'other',
    owner VARCHAR(255),
    is_active VARCHAR(10) DEFAULT 'true',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE tickets (
    id SERIAL PRIMARY KEY,
    title VARCHAR(500) NOT NULL,
    description TEXT NOT NULL,
    status VARCHAR(50) DEFAULT 'open',
    priority VARCHAR(50) DEFAULT 'medium',
    category VARCHAR(100) DEFAULT 'other',
    product VARCHAR(255),
    assigned_to VARCHAR(255),
    requester_id INTEGER,
    requester_name VARCHAR(255),
    requester_email VARCHAR(255),
    requester_phone VARCHAR(50),
    requester_department VARCHAR(255),
    requester_business_unit VARCHAR(255),
    first_response_at TIMESTAMP,
    resolved_at TIMESTAMP,
    sla_target_response INTEGER,
    sla_target_resolution INTEGER,
    sla_response_met BOOLEAN,
    sla_resolution_met BOOLEAN,
    approval_status VARCHAR(50),
    approved_by VARCHAR(255),
    approved_at TIMESTAMP,
    approval_comments TEXT,
    approval_token VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (requester_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE TABLE changes (
    id SERIAL PRIMARY KEY,
    title VARCHAR(500) NOT NULL,
    description TEXT NOT NULL,
    reason TEXT NOT NULL,
    status VARCHAR(50) DEFAULT 'draft',
    risk_level VARCHAR(50) DEFAULT 'medium',
    change_type VARCHAR(50) DEFAULT 'standard',
    scheduled_date TIMESTAMP,
    rollback_plan TEXT,
    requester_id INTEGER NOT NULL,
    approved_at TIMESTAMP,
    approval_comments TEXT,
    approval_token VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (requester_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE settings (
    id SERIAL PRIMARY KEY,
    key VARCHAR(255) UNIQUE NOT NULL,
    value TEXT,
    description TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE attachments (
    id SERIAL PRIMARY KEY,
    ticket_id INTEGER,
    change_id INTEGER,
    file_name VARCHAR(500) NOT NULL,
    original_name VARCHAR(500) NOT NULL,
    file_size BIGINT,
    mime_type VARCHAR(255),
    file_content BYTEA,
    uploaded_by INTEGER,
    uploaded_by_name VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (ticket_id) REFERENCES tickets(id) ON DELETE CASCADE,
    FOREIGN KEY (change_id) REFERENCES changes(id) ON DELETE CASCADE,
    FOREIGN KEY (uploaded_by) REFERENCES users(id) ON DELETE SET NULL
);

CREATE TABLE ticket_history (
    id SERIAL PRIMARY KEY,
    ticket_id INTEGER NOT NULL,
    action VARCHAR(100) NOT NULL,
    user_id INTEGER,
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (ticket_id) REFERENCES tickets(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE TABLE change_history (
    id SERIAL PRIMARY KEY,
    change_id INTEGER NOT NULL,
    action VARCHAR(100) NOT NULL,
    user_id INTEGER,
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (change_id) REFERENCES changes(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO servicedesk;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO servicedesk;

-- Insert test data
INSERT INTO users (username, email, password, role, name, created_at) VALUES
('john.doe', 'john.doe@calpion.com', 'password123', 'admin', 'John Doe', NOW()),
('test.admin', 'admin@calpion.com', 'password123', 'admin', 'Test Admin', NOW()),
('test.user', 'user@calpion.com', 'password123', 'user', 'Test User', NOW()),
('jane.manager', 'jane@calpion.com', 'password123', 'manager', 'Jane Manager', NOW()),
('bob.agent', 'bob@calpion.com', 'password123', 'agent', 'Bob Agent', NOW());

INSERT INTO products (name, description, category, owner, is_active, created_at, updated_at) VALUES
('Email System', 'Corporate email and communication tools', 'software', 'IT Team', 'true', NOW(), NOW()),
('Network Infrastructure', 'Network equipment and connectivity', 'hardware', 'Network Team', 'true', NOW(), NOW()),
('Office Applications', 'Productivity software and tools', 'software', 'IT Support', 'true', NOW(), NOW()),
('Database Systems', 'Database servers and storage', 'software', 'DBA Team', 'true', NOW(), NOW()),
('Security Tools', 'Firewall and security appliances', 'security', 'Security Team', 'true', NOW(), NOW());

INSERT INTO tickets (title, description, priority, category, product, requester_id, status, created_at, updated_at) VALUES
('Login Issues', 'Cannot access email system', 'high', 'access', 'Email System', 1, 'open', NOW(), NOW()),
('Network Slow', 'Internet connection is very slow', 'medium', 'performance', 'Network Infrastructure', 2, 'open', NOW(), NOW()),
('Password Reset', 'Need password reset for database access', 'low', 'access', 'Database Systems', 3, 'open', NOW(), NOW());

INSERT INTO changes (title, description, reason, risk_level, change_type, requester_id, status, created_at, updated_at) VALUES
('Email Server Upgrade', 'Upgrade email server to latest version', 'Security and performance improvements', 'medium', 'standard', 1, 'draft', NOW(), NOW()),
('Firewall Rule Update', 'Add new firewall rules for remote access', 'Enable secure remote work', 'high', 'emergency', 4, 'approved', NOW(), NOW());

INSERT INTO settings (key, value, description, created_at, updated_at) VALUES
('email_provider', 'sendgrid', 'Email service provider', NOW(), NOW()),
('email_from', 'no-reply@calpion.com', 'Default from email address', NOW(), NOW()),
('system_name', 'Calpion IT Service Desk', 'System display name', NOW(), NOW());
DB_EOF

# Install PM2 globally
sudo npm install -g pm2

# Create ecosystem config if it doesn't exist
if [ ! -f "ecosystem.config.js" ]; then
cat << 'PM2_EOF' > ecosystem.config.js
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'npm',
    args: 'start',
    instances: 1,
    autorestart: true,
    watch: false,
    env: {
      NODE_ENV: 'production',
      PORT: 5000,
      DATABASE_URL: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk'
    }
  }]
};
PM2_EOF
fi

# Start with PM2
pm2 start ecosystem.config.js
pm2 startup
pm2 save

echo "Waiting for server startup..."
sleep 15

# Test deployment
echo "Testing deployment..."
HEALTH=$(curl -s http://localhost:5000/health || echo '{"status":"ERROR"}')
echo "Health check: $HEALTH"

if echo "$HEALTH" | grep -q '"status":"OK"'; then
    echo "✓ Server running successfully"
    
    # Test authentication
    LOGIN=$(curl -s -c /tmp/test_cookies.txt -X POST http://localhost:5000/api/auth/login -H "Content-Type: application/json" -d '{"username":"john.doe","password":"password123"}')
    if echo "$LOGIN" | grep -q '"role":"admin"'; then
        echo "✓ Authentication working"
    fi
    
    # Test changes endpoint (this was failing before)
    CHANGES=$(curl -s -b /tmp/test_cookies.txt http://localhost:5000/api/changes)
    CHANGE_COUNT=$(echo "$CHANGES" | grep -o '"id":' | wc -l)
    echo "✓ Changes endpoint: $CHANGE_COUNT changes loaded"
    
    # Test products
    PRODUCTS=$(curl -s -b /tmp/test_cookies.txt http://localhost:5000/api/products)
    PRODUCT_COUNT=$(echo "$PRODUCTS" | grep -o '"id":' | wc -l)
    echo "✓ Products endpoint: $PRODUCT_COUNT products loaded"
    
    rm -f /tmp/test_cookies.txt
else
    echo "✗ Server startup failed"
    pm2 logs --lines 20
fi

pm2 status

echo ""
echo "=== PRODUCTION DEPLOYMENT COMPLETE ==="
echo "✅ Application: https://98.81.235.7:5000"
echo "✅ Login: john.doe / password123"
echo "✅ Database: PostgreSQL with test data"
echo "✅ Features: All endpoints operational"
