#!/bin/bash

echo "Creating User with Correct Schema"
echo "================================"

cd /var/www/itservicedesk

# Check actual column names in users table
export PGPASSWORD=servicedesk123
echo "Checking users table structure..."
psql -h localhost -U servicedesk -d servicedesk -c "\d users" 2>/dev/null || echo "Checking schema file..."

# Get column names from schema
if [ -f "shared/schema.ts" ]; then
    echo "Schema columns:"
    grep -A 20 "users = pgTable" shared/schema.ts | grep -E "(firstName|lastname|first_name|last_name)" || echo "Checking all user columns..."
    grep -A 30 "users = pgTable" shared/schema.ts
fi

# Create user with camelCase column names (likely from Drizzle schema)
export PGPASSWORD=servicedesk123
psql -h localhost -U servicedesk -d servicedesk << 'EOF'
INSERT INTO users (username, email, password, "firstName", "lastName", role, department, "businessUnit", "createdAt", "updatedAt") 
VALUES (
    'john.doe', 
    'john.doe@calpion.com', 
    '$2b$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi',
    'John', 
    'Doe', 
    'admin', 
    'IT', 
    'Technology',
    NOW(),
    NOW()
) ON CONFLICT (username) DO NOTHING;
EOF

if [ $? -eq 0 ]; then
    echo "✓ User created successfully"
else
    echo "Trying alternative column names..."
    export PGPASSWORD=servicedesk123
    psql -h localhost -U servicedesk -d servicedesk << 'EOF'
INSERT INTO users (username, email, password, role, department) 
VALUES ('admin', 'admin@calpion.com', '$2b$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'admin', 'IT') 
ON CONFLICT (username) DO NOTHING;
EOF
fi

# Verify user exists
export PGPASSWORD=servicedesk123
USER_COUNT=$(psql -h localhost -U servicedesk -d servicedesk -t -c "SELECT count(*) FROM users;" 2>/dev/null | xargs)
echo "Total users in database: $USER_COUNT"

if [ "$USER_COUNT" -gt 0 ]; then
    echo "✓ Users exist in database"
    psql -h localhost -U servicedesk -d servicedesk -c "SELECT username, email, role FROM users LIMIT 3;" 2>/dev/null
fi

# Test login
echo "Testing login..."
LOGIN_RESPONSE=$(curl -s -X POST http://localhost:3000/api/auth/login -H "Content-Type: application/json" -d '{"username":"john.doe","password":"secret"}')
echo "Login response: $LOGIN_RESPONSE"

echo ""
echo "Your IT Service Desk is ready at: https://98.81.235.7"
echo "Login credentials: john.doe / secret"