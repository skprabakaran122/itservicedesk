#!/bin/bash

# Fix PostgreSQL database connection and setup
cd /var/www/itservicedesk

echo "Checking PostgreSQL status and setting up database..."

# Check if PostgreSQL is running
if ! sudo systemctl is-active --quiet postgresql; then
    echo "Starting PostgreSQL service..."
    sudo systemctl start postgresql
    sudo systemctl enable postgresql
fi

# Create database and user if they don't exist
echo "Setting up database and user..."
sudo -u postgres psql << 'EOF'
-- Create database if not exists
SELECT 'CREATE DATABASE servicedesk' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'servicedesk')\gexec

-- Create user if not exists  
DO $$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = 'ubuntu') THEN
      CREATE USER ubuntu WITH PASSWORD 'password';
   END IF;
END
$$;

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE servicedesk TO ubuntu;
ALTER USER ubuntu CREATEDB;
EOF

# Test database connection
echo "Testing database connection..."
export DATABASE_URL="postgresql://ubuntu:password@localhost:5432/servicedesk"

# Try connection with the ubuntu user
if psql $DATABASE_URL -c "SELECT 1;" > /dev/null 2>&1; then
    echo "Database connection successful with ubuntu user"
else
    echo "Ubuntu user connection failed, trying postgres user..."
    export DATABASE_URL="postgresql://postgres@localhost:5432/servicedesk"
    
    if psql $DATABASE_URL -c "SELECT 1;" > /dev/null 2>&1; then
        echo "Database connection successful with postgres user"
    else
        echo "Database connection failed, creating database with postgres user..."
        sudo -u postgres createdb servicedesk 2>/dev/null || true
        export DATABASE_URL="postgresql://postgres@localhost:5432/servicedesk"
    fi
fi

# Create database schema and data
echo "Creating database schema and default data..."
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

-- Clear and insert users
DELETE FROM users WHERE username IN ('john.doe', 'test.admin', 'test.user');

INSERT INTO users (username, email, name, password, role, department, business_unit) VALUES 
('john.doe', 'john.doe@calpion.com', 'John Doe', 'password123', 'admin', 'IT', 'Technology'),
('test.admin', 'admin@calpion.com', 'Test Admin', 'password123', 'admin', 'IT', 'Technology'),
('test.user', 'user@calpion.com', 'Test User', 'password123', 'user', 'Operations', 'Business');

-- Insert sample products if not exists
INSERT INTO products (name, description, category, owner, active) 
SELECT 'Email System', 'Corporate email and messaging platform', 'Infrastructure', 'IT Department', true
WHERE NOT EXISTS (SELECT 1 FROM products WHERE name = 'Email System');

INSERT INTO products (name, description, category, owner, active) 
SELECT 'CRM Platform', 'Customer relationship management system', 'Business Applications', 'Sales Team', true
WHERE NOT EXISTS (SELECT 1 FROM products WHERE name = 'CRM Platform');

-- Verify setup
SELECT 'Database setup verification:' as status;
SELECT 'Users:' as table_name, count(*) as count FROM users;
SELECT 'Products:' as table_name, count(*) as count FROM products;
SELECT username, email, role FROM users;
EOF

# Update PM2 configuration with correct DATABASE_URL
echo "Updating PM2 configuration..."
cat > ecosystem.config.cjs << EOF
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
      DATABASE_URL: '$DATABASE_URL'
    },
    error_file: './logs/err.log',
    out_file: './logs/out.log',
    log_file: './logs/combined.log',
    time: true,
    max_memory_restart: '1G',
    restart_delay: 4000,
    watch: false,
    ignore_watch: ['node_modules', 'logs', 'dist'],
    kill_timeout: 5000
  }]
};
EOF

# Restart PM2 with new database configuration
echo "Restarting application with correct database connection..."
pm2 stop itservicedesk 2>/dev/null || true
pm2 delete itservicedesk 2>/dev/null || true

export DATABASE_URL
pm2 start ecosystem.config.cjs
pm2 save

sleep 8

# Test the application
echo "Testing application..."
if curl -s http://localhost:5000/health | grep -q "OK"; then
    echo "SUCCESS: Application is running"
    
    # Test authentication
    AUTH_TEST=$(curl -s -X POST http://localhost:5000/api/auth/login \
        -H "Content-Type: application/json" \
        -d '{"username":"john.doe","password":"password123"}')
    
    if echo "$AUTH_TEST" | grep -q "john.doe"; then
        echo "SUCCESS: Authentication working"
        
        SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "your-server-ip")
        echo ""
        echo "🎉 Calpion IT Service Desk is ready!"
        echo "Access: https://$SERVER_IP"
        echo "Login: john.doe / password123"
        echo ""
        echo "Database URL: $DATABASE_URL"
    else
        echo "Authentication failed. Response: $AUTH_TEST"
        echo "Checking application logs..."
        pm2 logs itservicedesk --lines 10
    fi
else
    echo "Application not responding"
    pm2 status
    pm2 logs itservicedesk --lines 10
fi