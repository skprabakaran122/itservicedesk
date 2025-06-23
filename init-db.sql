-- Initialize database with sample data for IT Service Desk

-- Create sample users (passwords are bcrypt hashed)
INSERT INTO users (username, email, password, role, name, assigned_products) VALUES
('john.doe', 'john.doe@calpion.com', '$2b$10$rQZ5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q', 'admin', 'John Doe', ARRAY['Windows 10', 'Office 365']),
('test.admin', 'admin@calpion.com', '$2b$10$rQZ5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q', 'admin', 'Test Admin', ARRAY['All Products']),
('test.user', 'user@calpion.com', '$2b$10$rQZ5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q', 'user', 'Test User', NULL),
('jane.smith', 'jane.smith@calpion.com', '$2b$10$rQZ5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q', 'technician', 'Jane Smith', ARRAY['Network Hardware', 'Security Systems'])
ON CONFLICT (username) DO NOTHING;

-- Create sample products
INSERT INTO products (name, category, description, is_active, owner) VALUES
('Windows 10', 'Operating System', 'Microsoft Windows 10 Enterprise', 'true', 'IT Department'),
('Office 365', 'Productivity Suite', 'Microsoft Office 365 Business Premium', 'true', 'IT Department'),
('Network Hardware', 'Infrastructure', 'Switches, routers, and network equipment', 'true', 'Network Team'),
('Security Systems', 'Security', 'Firewalls, antivirus, and security tools', 'true', 'Security Team'),
('Database Systems', 'Data Management', 'PostgreSQL, MySQL, and database services', 'true', 'Data Team')
ON CONFLICT (name) DO NOTHING;

-- Create sample settings
INSERT INTO settings (key, value, description) VALUES
('email_provider', 'sendgrid', 'Email service provider configuration'),
('sla_response_high', '60', 'SLA response time for high priority tickets (minutes)'),
('sla_response_medium', '240', 'SLA response time for medium priority tickets (minutes)'),
('sla_response_low', '480', 'SLA response time for low priority tickets (minutes)')
ON CONFLICT (key) DO NOTHING;