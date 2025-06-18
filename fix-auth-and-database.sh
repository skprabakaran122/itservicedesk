#!/bin/bash

# Complete database setup and authentication fix
cd /var/www/itservicedesk

export DATABASE_URL="postgresql://ubuntu:password@localhost:5432/servicedesk"

echo "Setting up complete database schema and users..."

# Create all required tables and default data
psql $DATABASE_URL << 'EOF'
-- Users table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    password VARCHAR(255) NOT NULL,
    role VARCHAR(20) DEFAULT 'user',
    department VARCHAR(100),
    business_unit VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Products table  
CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(100),
    owner VARCHAR(100),
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tickets table
CREATE TABLE IF NOT EXISTS tickets (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    status VARCHAR(50) DEFAULT 'open',
    priority VARCHAR(20) DEFAULT 'medium',
    product_id INTEGER REFERENCES products(id),
    requester_id INTEGER REFERENCES users(id),
    requester_email VARCHAR(100),
    requester_name VARCHAR(100),
    assigned_to INTEGER REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Changes table
CREATE TABLE IF NOT EXISTS changes (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    status VARCHAR(50) DEFAULT 'pending',
    risk VARCHAR(20) DEFAULT 'low',
    business_justification TEXT,
    implementation_plan TEXT,
    requester_id INTEGER REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Session table
CREATE TABLE IF NOT EXISTS user_sessions (
    sid varchar NOT NULL COLLATE "default",
    sess json NOT NULL,
    expire timestamp(6) NOT NULL
) WITH (OIDS=FALSE);

CREATE INDEX IF NOT EXISTS "IDX_session_expire" ON "user_sessions" ("expire");

-- Clear existing users and insert fresh ones
DELETE FROM users;

-- Insert default users
INSERT INTO users (username, email, name, password, role, department, business_unit) VALUES 
('john.doe', 'john.doe@calpion.com', 'John Doe', 'password123', 'admin', 'IT', 'Technology'),
('test.admin', 'admin@calpion.com', 'Test Admin', 'password123', 'admin', 'IT', 'Technology'),
('test.user', 'user@calpion.com', 'Test User', 'password123', 'user', 'Operations', 'Business');

-- Insert sample products
INSERT INTO products (name, description, category, owner, active) VALUES 
('Email System', 'Corporate email and messaging platform', 'Infrastructure', 'IT Department', true),
('CRM Platform', 'Customer relationship management system', 'Business Applications', 'Sales Team', true),
('Network Infrastructure', 'Core network and connectivity services', 'Infrastructure', 'Network Team', true),
('Security Systems', 'Security monitoring and access control', 'Security', 'Security Team', true)
ON CONFLICT DO NOTHING;

-- Insert sample tickets
INSERT INTO tickets (title, description, status, priority, product_id, requester_email, requester_name) VALUES 
('Email server slow response', 'Users reporting slow email delivery and sync issues', 'open', 'high', 1, 'sarah.smith@calpion.com', 'Sarah Smith'),
('CRM login issues', 'Multiple users cannot access CRM system', 'in_progress', 'medium', 2, 'mike.jones@calpion.com', 'Mike Jones'),
('Network connectivity problems', 'Intermittent network drops in Building A', 'open', 'high', 3, 'lisa.brown@calpion.com', 'Lisa Brown');

-- Insert sample changes
INSERT INTO changes (title, description, risk, business_justification, implementation_plan, requester_id) VALUES 
('Upgrade email server', 'Upgrade to latest email server version for better performance', 'medium', 'Improve user productivity and reduce support tickets', 'Schedule maintenance window, backup data, upgrade software', 1),
('Implement new firewall rules', 'Add additional security rules to protect against threats', 'low', 'Enhance security posture', 'Test rules in staging, deploy to production', 1);

-- Verify data
SELECT 'Users created:' as info, count(*) as count FROM users;
SELECT username, email, role FROM users;
SELECT 'Products created:' as info, count(*) as count FROM products;  
SELECT 'Tickets created:' as info, count(*) as count FROM tickets;
SELECT 'Changes created:' as info, count(*) as count FROM changes;
EOF

echo ""
echo "Database setup complete!"
echo ""
echo "Login credentials:"
echo "- john.doe / password123 (admin)"
echo "- test.admin / password123 (admin)"
echo "- test.user / password123 (user)"
echo ""
echo "Restarting PM2 to ensure fresh connection..."

# Restart PM2 to pick up database changes
pm2 restart itservicedesk

sleep 5

# Test authentication
echo "Testing authentication..."
AUTH_TEST=$(curl -s -X POST http://localhost:5000/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"username":"john.doe","password":"password123"}')

if echo "$AUTH_TEST" | grep -q "john.doe"; then
    echo "SUCCESS: Authentication working"
    echo "Your Calpion IT Service Desk is ready!"
else
    echo "Authentication test failed. Response:"
    echo "$AUTH_TEST"
fi