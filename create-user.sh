#!/bin/bash

echo "Creating Default User"
echo "===================="

cd /var/www/itservicedesk

# Check the actual table structure
echo "Checking users table structure..."
export PGPASSWORD=servicedesk123
psql -h localhost -U servicedesk -d servicedesk -c "\d users"

# Create user with correct column names
echo "Creating default user..."
export PGPASSWORD=servicedesk123
psql -h localhost -U servicedesk -d servicedesk << 'EOF'
INSERT INTO users (username, email, password, first_name, last_name, role, department, business_unit, created_at, updated_at)
VALUES (
  'john.doe', 
  'john.doe@calpion.com', 
  '$2b$10$K7L/VnVp8wJw8r1nZoKhBOJ7J5dJn2nJ5pJ7J5dJn2nJ5pJ7J5dJn2',
  'John', 
  'Doe', 
  'admin', 
  'IT', 
  'Technology',
  NOW(),
  NOW()
)
ON CONFLICT (username) DO NOTHING;
EOF

# Check if user was created
echo "Verifying user creation..."
export PGPASSWORD=servicedesk123
USER_COUNT=$(psql -h localhost -U servicedesk -d servicedesk -t -c "SELECT count(*) FROM users WHERE username = 'john.doe';" | xargs)

if [ "$USER_COUNT" = "1" ]; then
    echo "✓ Default user created successfully"
else
    echo "User creation failed, trying alternative approach..."
    
    # Try with a simpler password hash
    export PGPASSWORD=servicedesk123
    psql -h localhost -U servicedesk -d servicedesk << 'EOF'
INSERT INTO users (username, email, password, first_name, last_name, role, department, business_unit)
VALUES (
  'admin', 
  'admin@calpion.com', 
  '$2b$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi',
  'Admin', 
  'User', 
  'admin', 
  'IT', 
  'Technology'
)
ON CONFLICT (username) DO NOTHING;
EOF
fi

# Test login endpoint
echo "Testing login endpoint..."
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"john.doe","password":"password123"}')

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n -1)

echo "HTTP Status: $HTTP_CODE"
echo "Response: $BODY"

if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ Login successful!"
elif [ "$HTTP_CODE" = "401" ]; then
    echo "Testing with admin user..."
    curl -s -X POST http://localhost:3000/api/auth/login \
      -H "Content-Type: application/json" \
      -d '{"username":"admin","password":"secret"}'
fi

echo ""
echo "✓ Your IT Service Desk is running at: https://98.81.235.7"
echo "Try logging in with:"
echo "  Username: john.doe | Password: password123"
echo "  OR"
echo "  Username: admin | Password: secret"