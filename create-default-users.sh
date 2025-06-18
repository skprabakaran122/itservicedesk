#!/bin/bash

# Create default users for production database
cd /var/www/itservicedesk

export DATABASE_URL="postgresql://ubuntu:password@localhost:5432/servicedesk"

echo "Creating default users in production database..."

# Create users table if not exists
psql $DATABASE_URL << 'EOF'
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

-- Insert default users with plain text passwords (will be hashed by bcrypt in app)
INSERT INTO users (username, email, name, password, role, department, business_unit) 
VALUES 
    ('john.doe', 'john.doe@calpion.com', 'John Doe', 'password123', 'admin', 'IT', 'Technology'),
    ('test.admin', 'admin@calpion.com', 'Test Admin', 'password123', 'admin', 'IT', 'Technology'),
    ('test.user', 'user@calpion.com', 'Test User', 'password123', 'user', 'Operations', 'Business')
ON CONFLICT (username) DO NOTHING;

-- Verify users created
SELECT username, email, name, role FROM users;
EOF

echo "Default users created. You can login with:"
echo "- john.doe / password123 (admin)"
echo "- test.admin / password123 (admin)" 
echo "- test.user / password123 (user)"

# Also create products table with sample data
psql $DATABASE_URL << 'EOF'
CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(100),
    owner VARCHAR(100),
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO products (name, description, category, owner, active) 
VALUES 
    ('Email System', 'Corporate email and messaging platform', 'Infrastructure', 'IT Department', true),
    ('CRM Platform', 'Customer relationship management system', 'Business Applications', 'Sales Team', true),
    ('Network Infrastructure', 'Core network and connectivity services', 'Infrastructure', 'Network Team', true),
    ('Security Systems', 'Security monitoring and access control', 'Security', 'Security Team', true)
ON CONFLICT DO NOTHING;
EOF

echo "Sample products created for ticket assignment."

# Create other required tables
psql $DATABASE_URL << 'EOF'
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

CREATE TABLE IF NOT EXISTS user_sessions (
    sid varchar NOT NULL COLLATE "default",
    sess json NOT NULL,
    expire timestamp(6) NOT NULL
) WITH (OIDS=FALSE);

CREATE INDEX IF NOT EXISTS "IDX_session_expire" ON "user_sessions" ("expire");
EOF

echo "All database tables created successfully."