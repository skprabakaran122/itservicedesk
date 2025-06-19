-- Initialize database schema and sample data
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    role VARCHAR(50) DEFAULT 'user',
    department VARCHAR(255),
    business_unit VARCHAR(255),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Products table
CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(255),
    owner VARCHAR(255),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tickets table
CREATE TABLE IF NOT EXISTS tickets (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    status VARCHAR(50) DEFAULT 'open',
    priority VARCHAR(50) DEFAULT 'medium',
    category VARCHAR(255),
    product_id INTEGER REFERENCES products(id),
    requester_email VARCHAR(255),
    requester_name VARCHAR(255),
    assigned_to INTEGER REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP,
    due_date TIMESTAMP,
    approval_status VARCHAR(50),
    approval_token VARCHAR(255)
);

-- Changes table
CREATE TABLE IF NOT EXISTS changes (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    status VARCHAR(50) DEFAULT 'pending',
    priority VARCHAR(50) DEFAULT 'medium',
    category VARCHAR(255),
    risk_level VARCHAR(50) DEFAULT 'low',
    requested_by VARCHAR(255),
    approved_by VARCHAR(255),
    scheduled_date TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Settings table
CREATE TABLE IF NOT EXISTS settings (
    id SERIAL PRIMARY KEY,
    key VARCHAR(255) UNIQUE NOT NULL,
    value TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample data
INSERT INTO users (username, password, email, full_name, role, department) VALUES
('test.admin', 'password123', 'admin@calpion.com', 'Test Administrator', 'admin', 'IT'),
('test.user', 'password123', 'user@calpion.com', 'Test User', 'user', 'Finance'),
('john.doe', 'password123', 'john.doe@calpion.com', 'John Doe', 'agent', 'IT'),
('jane.smith', 'password123', 'jane.smith@calpion.com', 'Jane Smith', 'manager', 'Operations')
ON CONFLICT (username) DO NOTHING;

INSERT INTO products (name, description, category, owner) VALUES
('Email System', 'Corporate email infrastructure', 'Communication', 'IT Department'),
('Customer Database', 'Main customer relationship management system', 'Database', 'Sales Team'),
('Financial Software', 'Accounting and financial management tools', 'Finance', 'Finance Team'),
('Network Infrastructure', 'Corporate network and security systems', 'Infrastructure', 'IT Department'),
('HR Portal', 'Human resources management system', 'HR', 'HR Department')
ON CONFLICT DO NOTHING;

INSERT INTO tickets (title, description, status, priority, category, product_id, requester_email, requester_name) VALUES
('Email not working', 'Unable to send emails from Outlook', 'open', 'high', 'Email', 1, 'user@example.com', 'Sample User'),
('Database connection slow', 'Customer database queries taking too long', 'in_progress', 'medium', 'Performance', 2, 'sales@example.com', 'Sales Manager'),
('Password reset request', 'Need to reset password for financial system', 'resolved', 'low', 'Access', 3, 'finance@example.com', 'Finance User')
ON CONFLICT DO NOTHING;

INSERT INTO changes (title, description, status, priority, category, risk_level, requested_by) VALUES
('Update antivirus software', 'Deploy latest antivirus definitions to all workstations', 'pending', 'medium', 'Security', 'low', 'IT Admin'),
('Network firewall update', 'Apply security patches to main firewall', 'approved', 'high', 'Infrastructure', 'medium', 'Network Manager')
ON CONFLICT DO NOTHING;

INSERT INTO settings (key, value) VALUES
('email_provider', 'sendgrid'),
('email_from', 'no-reply@calpion.com'),
('sendgrid_api_key', ''),
('smtp_host', ''),
('smtp_port', '587')
ON CONFLICT (key) DO NOTHING;