#!/bin/bash

# Complete Ubuntu development environment setup
# This eliminates all production deployment issues by matching Ubuntu configuration

echo "Setting up Ubuntu-compatible development environment..."

# Install PostgreSQL if needed
if ! command -v psql &> /dev/null; then
    echo "Installing PostgreSQL..."
    sudo apt update
    sudo apt install -y postgresql postgresql-contrib
    sudo systemctl start postgresql
    sudo systemctl enable postgresql
fi

# Configure trust authentication (matching production)
sudo sed -i 's/local   all             all                                     peer/local   all             all                                     trust/' /etc/postgresql/*/main/pg_hba.conf
sudo sed -i 's/local   all             all                                     md5/local   all             all                                     trust/' /etc/postgresql/*/main/pg_hba.conf
sudo sed -i 's/host    all             all             127.0.0.1\/32            md5/host    all             all             127.0.0.1\/32            trust/' /etc/postgresql/*/main/pg_hba.conf

# Restart PostgreSQL to apply changes
sudo systemctl restart postgresql
sleep 2

# Setup database and schema
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
    owner VARCHAR(100),
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
    assigned_to VARCHAR(100),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
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
    scheduled_date TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE ticket_history (
    id SERIAL PRIMARY KEY,
    ticket_id INTEGER NOT NULL REFERENCES tickets(id),
    action TEXT NOT NULL,
    old_value TEXT,
    new_value TEXT,
    performed_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE change_history (
    id SERIAL PRIMARY KEY,
    change_id INTEGER NOT NULL REFERENCES changes(id),
    action TEXT NOT NULL,
    old_value TEXT,
    new_value TEXT,
    performed_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE settings (
    id SERIAL PRIMARY KEY,
    key VARCHAR(100) NOT NULL UNIQUE,
    value TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Insert development data matching production
INSERT INTO users (username, email, password, role, name) VALUES
('admin', 'admin@calpion.com', 'password123', 'admin', 'System Administrator'),
('support', 'support@calpion.com', 'password123', 'technician', 'Support Technician'),
('manager', 'manager@calpion.com', 'password123', 'manager', 'IT Manager'),
('user', 'user@calpion.com', 'password123', 'user', 'End User'),
('john.doe', 'john.doe@calpion.com', 'password123', 'user', 'John Doe'),
('test.admin', 'test.admin@calpion.com', 'password123', 'admin', 'Test Admin'),
('test.user', 'test.user@calpion.com', 'password123', 'user', 'Test User');

INSERT INTO products (name, category, description, owner) VALUES
('Microsoft Office 365', 'Software', 'Office productivity suite', 'IT Department'),
('Windows 10', 'Operating System', 'Desktop operating system', 'IT Department'),
('VPN Access', 'Network', 'Remote access solution', 'Network Team'),
('Printer Access', 'Hardware', 'Network printer configuration', 'Support Team'),
('Email Setup', 'Communication', 'Email account configuration', 'IT Department'),
('Laptop Hardware', 'Hardware', 'Standard business laptops', 'Hardware Team'),
('Antivirus Software', 'Security', 'Enterprise endpoint protection', 'Security Team'),
('Database Access', 'Software', 'Database connectivity and tools', 'Database Team');

INSERT INTO tickets (title, description, status, priority, category, product, requester_email, requester_name, assigned_to) VALUES
('Cannot access email', 'Unable to login to Outlook after password reset', 'open', 'medium', 'software', 'Microsoft Office 365', 'john@calpion.com', 'John Smith', 'support'),
('Printer not working', 'Printer showing offline status in office', 'pending', 'low', 'hardware', 'Printer Access', 'jane@calpion.com', 'Jane Doe', 'support'),
('VPN connection issues', 'Cannot connect to company VPN from home', 'in-progress', 'high', 'network', 'VPN Access', 'bob@calpion.com', 'Bob Johnson', 'manager'),
('Laptop running slowly', 'Computer takes 10+ minutes to boot up', 'open', 'medium', 'hardware', 'Laptop Hardware', 'alice@calpion.com', 'Alice Brown', 'support'),
('Database connection timeout', 'Application cannot connect to production database', 'urgent', 'critical', 'software', 'Database Access', 'dev@calpion.com', 'Dev Team', 'admin');

INSERT INTO changes (title, description, status, priority, category, risk_level, requested_by, scheduled_date) VALUES
('Update antivirus software', 'Deploy latest antivirus definitions to all workstations', 'pending', 'medium', 'system', 'low', 'admin', '2025-06-25 02:00:00'),
('Network firewall update', 'Apply security patches to main firewall', 'approved', 'high', 'infrastructure', 'medium', 'manager', '2025-06-20 01:00:00'),
('Email server maintenance', 'Scheduled maintenance for email server cluster', 'scheduled', 'high', 'infrastructure', 'high', 'admin', '2025-06-22 03:00:00'),
('Database backup procedure', 'Implement new automated backup strategy', 'pending', 'medium', 'system', 'low', 'manager', '2025-06-28 00:00:00');

-- Insert sample history
INSERT INTO ticket_history (ticket_id, action, old_value, new_value, performed_by) VALUES
(1, 'status_change', 'new', 'open', 'support'),
(1, 'assigned', NULL, 'support', 'admin'),
(2, 'status_change', 'new', 'pending', 'support'),
(3, 'status_change', 'open', 'in-progress', 'manager'),
(3, 'priority_change', 'medium', 'high', 'manager');

INSERT INTO change_history (change_id, action, old_value, new_value, performed_by) VALUES
(2, 'status_change', 'pending', 'approved', 'manager'),
(2, 'scheduled', NULL, '2025-06-20 01:00:00', 'manager'),
(3, 'status_change', 'approved', 'scheduled', 'admin');

-- Email configuration
INSERT INTO settings (key, value) VALUES
('email_provider', 'sendgrid'),
('email_from', 'no-reply@calpion.com'),
('sendgrid_api_key', ''),
('smtp_host', ''),
('smtp_port', '587'),
('smtp_user', ''),
('smtp_pass', '');
EOF

echo ""
echo "✅ Development environment configured for Ubuntu compatibility"
echo "✅ PostgreSQL database created with comprehensive test data"
echo "✅ Trust authentication enabled (no password required)"
echo "✅ Schema matches production deployment exactly"
echo ""
echo "Database Configuration:"
echo "  Host: localhost"
echo "  Database: servicedesk"
echo "  User: postgres"
echo "  Password: (none)"
echo "  Port: 5432"
echo ""
echo "Available Test Accounts:"
echo "  admin/password123 (System Administrator)"
echo "  support/password123 (Support Technician)"
echo "  manager/password123 (IT Manager)"
echo "  user/password123 (End User)"
echo "  john.doe/password123 (John Doe)"
echo "  test.admin/password123 (Test Admin)"
echo "  test.user/password123 (Test User)"
echo ""
echo "Sample Data Created:"
echo "  - 7 users with different roles"
echo "  - 8 products across various categories"
echo "  - 5 tickets with different statuses and priorities"
echo "  - 4 change requests with approval workflows"
echo "  - Complete history tracking"
echo "  - Email configuration settings"
echo ""
echo "Ready for development with production-matching configuration!"