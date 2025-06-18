#!/bin/bash

# Fix database schema mismatch and user authentication
cd /var/www/itservicedesk

echo "Fixing database schema mismatch..."

# First, check what columns exist in users table
sudo -u postgres psql servicedesk << 'EOF'
\d users
EOF

# Update users table to match expected schema
sudo -u postgres psql servicedesk << 'EOF'
-- Add missing columns to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS department VARCHAR(100);
ALTER TABLE users ADD COLUMN IF NOT EXISTS business_unit VARCHAR(100);
ALTER TABLE users ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- Add missing columns to products table  
ALTER TABLE products ADD COLUMN IF NOT EXISTS owner VARCHAR(100);

-- Add missing columns to tickets table
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS product_id INTEGER;
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS requester_id INTEGER;
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS requester_email VARCHAR(100);
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS requester_name VARCHAR(100);
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS assigned_to INTEGER;
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- Update existing admin user password to match expected format
UPDATE users SET password = 'password123' WHERE username = 'admin';

-- Insert the expected users if they don't exist
INSERT INTO users (username, email, name, password, role, department, business_unit) 
SELECT 'john.doe', 'john.doe@calpion.com', 'John Doe', 'password123', 'admin', 'IT', 'Technology'
WHERE NOT EXISTS (SELECT 1 FROM users WHERE username = 'john.doe');

INSERT INTO users (username, email, name, password, role, department, business_unit) 
SELECT 'test.admin', 'admin@calpion.com', 'Test Admin', 'password123', 'admin', 'IT', 'Technology'
WHERE NOT EXISTS (SELECT 1 FROM users WHERE username = 'test.admin');

INSERT INTO users (username, email, name, password, role, department, business_unit) 
SELECT 'test.user', 'user@calpion.com', 'Test User', 'password123', 'user', 'Operations', 'Business'
WHERE NOT EXISTS (SELECT 1 FROM users WHERE username = 'test.user');

-- Update products with owner information
UPDATE products SET owner = 'IT Department' WHERE owner IS NULL;

-- Show final user list
SELECT username, email, role, password FROM users WHERE username IN ('admin', 'john.doe', 'test.admin', 'test.user');
EOF

echo "Schema updated, restarting application..."

# Restart PM2 to pick up schema changes
pm2 restart itservicedesk
sleep 5

# Test with multiple user accounts
echo "Testing authentication with different accounts..."

# Test admin user
AUTH_ADMIN=$(curl -s -X POST http://localhost:5000/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"username":"admin","password":"password123"}')

if echo "$AUTH_ADMIN" | grep -q "admin"; then
    echo "SUCCESS: admin/password123 working"
else
    echo "admin failed: $AUTH_ADMIN"
fi

# Test john.doe user  
AUTH_JOHN=$(curl -s -X POST http://localhost:5000/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"username":"john.doe","password":"password123"}')

if echo "$AUTH_JOHN" | grep -q "john.doe"; then
    echo "SUCCESS: john.doe/password123 working"
else
    echo "john.doe failed: $AUTH_JOHN"
fi

# Test application endpoints
echo "Testing API endpoints..."
USERS_API=$(curl -s http://localhost:5000/api/users)
if echo "$USERS_API" | grep -q "admin\|john.doe"; then
    echo "SUCCESS: Users API working"
else
    echo "Users API failed: $USERS_API"
fi

PRODUCTS_API=$(curl -s http://localhost:5000/api/products)
if echo "$PRODUCTS_API" | grep -q "name"; then
    echo "SUCCESS: Products API working"
else
    echo "Products API failed: $PRODUCTS_API"
fi

# Check PM2 logs for any errors
echo "Checking for application errors..."
pm2 logs itservicedesk --lines 5 --nostream

SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "your-server-ip")
echo ""
echo "Database schema fixed. Available logins:"
echo "- admin / password123"
echo "- john.doe / password123"  
echo "- test.admin / password123"
echo "- test.user / password123"
echo ""
echo "Access: https://$SERVER_IP"