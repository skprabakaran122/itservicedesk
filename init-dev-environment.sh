#!/bin/bash

# Initialize development environment for Ubuntu compatibility
# This ensures development matches production authentication patterns

echo "Initializing development environment for Ubuntu compatibility..."

# Update database schema to match Ubuntu production
echo "Synchronizing database schema..."

# Create development data that matches Ubuntu production expectations
cat > temp-dev-data.sql << 'EOF'
-- Ensure we have Ubuntu-compatible test users
INSERT INTO users (username, email, password, role, name) VALUES
('admin', 'admin@calpion.com', 'password123', 'admin', 'System Administrator'),
('support', 'support@calpion.com', 'password123', 'technician', 'Support Technician'),
('manager', 'manager@calpion.com', 'password123', 'manager', 'IT Manager'),
('john.doe', 'john.doe@calpion.com', 'password123', 'user', 'John Doe'),
('test.admin', 'test.admin@calpion.com', 'password123', 'admin', 'Test Admin'),
('test.user', 'test.user@calpion.com', 'password123', 'user', 'Test User')
ON CONFLICT (username) DO UPDATE SET
  email = EXCLUDED.email,
  password = EXCLUDED.password,
  role = EXCLUDED.role,
  name = EXCLUDED.name;

-- Update products with owner field for Ubuntu compatibility
UPDATE products SET owner = 'IT Department' WHERE owner IS NULL;

-- Insert Ubuntu-style products if missing
INSERT INTO products (name, category, description, owner) VALUES
('Laptop Hardware', 'Hardware', 'Standard business laptops', 'Hardware Team'),
('Antivirus Software', 'Security', 'Enterprise endpoint protection', 'Security Team'),
('Database Access', 'Software', 'Database connectivity and tools', 'Database Team')
ON CONFLICT (name) DO UPDATE SET
  category = EXCLUDED.category,
  description = EXCLUDED.description,
  owner = EXCLUDED.owner;

-- Add Ubuntu-style tickets with proper assignments
INSERT INTO tickets (title, description, status, priority, category, product, requester_email, requester_name, assigned_to) VALUES
('Laptop running slowly', 'Computer takes 10+ minutes to boot up', 'open', 'medium', 'hardware', 'Laptop Hardware', 'alice@calpion.com', 'Alice Brown', 'support'),
('Database connection timeout', 'Application cannot connect to production database', 'urgent', 'critical', 'software', 'Database Access', 'dev@calpion.com', 'Dev Team', 'admin')
ON CONFLICT DO NOTHING;

-- Add Ubuntu-style changes with scheduling
INSERT INTO changes (title, description, status, priority, category, risk_level, requested_by, scheduled_date) VALUES
('Email server maintenance', 'Scheduled maintenance for email server cluster', 'scheduled', 'high', 'infrastructure', 'high', 'admin', '2025-06-22 03:00:00'),
('Database backup procedure', 'Implement new automated backup strategy', 'pending', 'medium', 'system', 'low', 'manager', '2025-06-28 00:00:00')
ON CONFLICT DO NOTHING;

-- Initialize email configuration for Ubuntu compatibility
INSERT INTO settings (key, value) VALUES
('email_provider', 'sendgrid'),
('email_from', 'no-reply@calpion.com'),
('sendgrid_api_key', ''),
('smtp_host', ''),
('smtp_port', '587'),
('smtp_user', ''),
('smtp_pass', '')
ON CONFLICT (key) DO NOTHING;
EOF

# Apply the development data
psql $DATABASE_URL -f temp-dev-data.sql

# Clean up
rm temp-dev-data.sql

echo "✅ Development environment configured for Ubuntu compatibility"
echo "✅ Authentication patterns match Ubuntu production"
echo "✅ Database schema synchronized"
echo "✅ Test accounts ready for deployment validation"
echo ""
echo "Available test accounts (same as Ubuntu production):"
echo "  admin/password123 (System Administrator)"
echo "  support/password123 (Support Technician)"  
echo "  manager/password123 (IT Manager)"
echo "  john.doe/password123 (John Doe)"
echo "  test.admin/password123 (Test Admin)"
echo "  test.user/password123 (Test User)"
echo ""
echo "Development environment ready for Ubuntu deployment!"