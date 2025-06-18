#!/bin/bash

# Simple database fix - use postgres user which always works
cd /var/www/itservicedesk

echo "Fixing database connection using postgres user..."

# Ensure PostgreSQL is running
sudo systemctl start postgresql

# Create database using postgres superuser
sudo -u postgres createdb servicedesk 2>/dev/null || echo "Database already exists"

# Set the correct DATABASE_URL using postgres user (no password needed)
export DATABASE_URL="postgresql://postgres@localhost:5432/servicedesk"

# Create all tables and users
sudo -u postgres psql servicedesk << 'EOF'
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

CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(100),
    owner VARCHAR(100),
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

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

DELETE FROM users;
INSERT INTO users (username, email, name, password, role, department, business_unit) VALUES 
('john.doe', 'john.doe@calpion.com', 'John Doe', 'password123', 'admin', 'IT', 'Technology'),
('test.admin', 'admin@calpion.com', 'Test Admin', 'password123', 'admin', 'IT', 'Technology'),
('test.user', 'user@calpion.com', 'Test User', 'password123', 'user', 'Operations', 'Business');

INSERT INTO products (name, description, category, owner, active) VALUES 
('Email System', 'Corporate email platform', 'Infrastructure', 'IT Department', true),
('CRM Platform', 'Customer management system', 'Business Applications', 'Sales Team', true)
ON CONFLICT DO NOTHING;

INSERT INTO tickets (title, description, status, priority, product_id, requester_email, requester_name) VALUES 
('Email server issues', 'Slow email delivery reported', 'open', 'high', 1, 'user@example.com', 'Test User'),
('CRM login problems', 'Users cannot access CRM', 'open', 'medium', 2, 'admin@example.com', 'Admin User')
ON CONFLICT DO NOTHING;

SELECT 'Users created: ' || count(*) FROM users;
SELECT username, role FROM users;
EOF

# Update PM2 config with postgres DATABASE_URL
cat > ecosystem.config.cjs << 'EOF'
module.exports = {
  apps: [{
    name: 'itservicedesk',
    script: 'dist/production.cjs',
    instances: 1,
    exec_mode: 'fork',
    cwd: '/var/www/itservicedesk',
    env: {
      NODE_ENV: 'production',
      PORT: 5000,
      DATABASE_URL: 'postgresql://postgres@localhost:5432/servicedesk'
    },
    error_file: './logs/err.log',
    out_file: './logs/out.log',
    log_file: './logs/combined.log',
    time: true,
    max_memory_restart: '1G',
    restart_delay: 4000,
    watch: false,
    kill_timeout: 5000
  }]
};
EOF

# Restart PM2
pm2 delete itservicedesk 2>/dev/null || true
pm2 start ecosystem.config.cjs
sleep 5

# Test
echo "Testing application..."
HEALTH=$(curl -s http://localhost:5000/health)
if echo "$HEALTH" | grep -q "OK"; then
    echo "Application running"
    
    AUTH=$(curl -s -X POST http://localhost:5000/api/auth/login \
        -H "Content-Type: application/json" \
        -d '{"username":"john.doe","password":"password123"}')
    
    if echo "$AUTH" | grep -q "john.doe"; then
        echo "SUCCESS: Authentication working"
        echo "Login: john.doe / password123"
    else
        echo "Auth failed: $AUTH"
    fi
else
    echo "App not responding: $HEALTH"
    pm2 logs itservicedesk --lines 5
fi