#!/bin/bash

# Setup development database to match Ubuntu production
echo "Setting up development database to match Ubuntu production..."

# Install PostgreSQL if not already installed
if ! command -v psql &> /dev/null; then
    echo "Installing PostgreSQL..."
    sudo apt update
    sudo apt install -y postgresql postgresql-contrib
    sudo systemctl start postgresql
    sudo systemctl enable postgresql
fi

# Configure PostgreSQL for trust authentication (matching production)
echo "Configuring PostgreSQL authentication..."
sudo -u postgres psql -c "ALTER USER postgres PASSWORD '';" 2>/dev/null || true

# Create database and schema
sudo -u postgres psql << 'EOF'
DROP DATABASE IF EXISTS servicedesk;
CREATE DATABASE servicedesk;
\c servicedesk

CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username TEXT NOT NULL UNIQUE,
    email TEXT NOT NULL UNIQUE,
    password TEXT NOT NULL,
    role VARCHAR(20) NOT NULL,
    name TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    category VARCHAR(50) NOT NULL,
    description TEXT,
    is_active VARCHAR(10) DEFAULT 'true',
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE tickets (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    status VARCHAR(20) NOT NULL,
    priority VARCHAR(20) NOT NULL,
    category VARCHAR(50) NOT NULL,
    product VARCHAR(100),
    requester_email TEXT,
    requester_name TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE changes (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    status VARCHAR(20) NOT NULL,
    priority VARCHAR(20) NOT NULL,
    category VARCHAR(50) NOT NULL,
    risk_level VARCHAR(20) NOT NULL,
    requested_by TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Insert test data matching production
INSERT INTO users (username, email, password, role, name) VALUES
('admin', 'admin@calpion.com', 'password123', 'admin', 'System Administrator'),
('support', 'support@calpion.com', 'password123', 'technician', 'Support Technician'),
('manager', 'manager@calpion.com', 'password123', 'manager', 'IT Manager'),
('user', 'user@calpion.com', 'password123', 'user', 'End User');

INSERT INTO products (name, category, description) VALUES
('Microsoft Office 365', 'Software', 'Office productivity suite'),
('Windows 10', 'Operating System', 'Desktop operating system'),
('VPN Access', 'Network', 'Remote access solution'),
('Printer Access', 'Hardware', 'Network printer configuration'),
('Email Setup', 'Communication', 'Email account configuration');

INSERT INTO tickets (title, description, status, priority, category, product, requester_email, requester_name) VALUES
('Cannot access email', 'Unable to login to Outlook', 'open', 'medium', 'software', 'Microsoft Office 365', 'john@calpion.com', 'John Smith'),
('Printer not working', 'Printer showing offline status', 'pending', 'low', 'hardware', 'Printer Access', 'jane@calpion.com', 'Jane Doe'),
('VPN connection issues', 'Cannot connect to company VPN', 'in-progress', 'high', 'network', 'VPN Access', 'bob@calpion.com', 'Bob Johnson');

INSERT INTO changes (title, description, status, priority, category, risk_level, requested_by) VALUES
('Update antivirus software', 'Deploy latest antivirus definitions', 'pending', 'medium', 'system', 'low', 'admin'),
('Network firewall update', 'Apply security patches to firewall', 'approved', 'high', 'infrastructure', 'medium', 'manager');
EOF

echo "✅ Development database configured to match Ubuntu production"
echo "✅ Trust authentication enabled"
echo "✅ Sample data inserted"
echo ""
echo "Database details:"
echo "  Host: localhost"
echo "  Database: servicedesk" 
echo "  User: postgres"
echo "  Password: (none - trust auth)"
echo ""
echo "Test accounts:"
echo "  admin/password123"
echo "  support/password123"
echo "  manager/password123"
echo "  user/password123"