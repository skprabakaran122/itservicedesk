#!/bin/bash

echo "Debug Admin Login Issue"
echo "====================="

cat << 'EOF'
# Check admin user in Ubuntu database and debug login:

cd /var/www/itservicedesk

echo "=== CHECKING ADMIN USER IN DATABASE ==="
psql -U servicedesk -d servicedesk -c "SELECT id, username, email, password, role, name FROM users WHERE username LIKE '%admin%' OR role = 'admin';"

echo ""
echo "=== CHECKING ALL USERS ==="
psql -U servicedesk -d servicedesk -c "SELECT id, username, email, password, role, name FROM users ORDER BY id;"

echo ""
echo "=== TESTING ADMIN LOGIN WITH DETAILED LOGGING ==="
curl -v -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.admin","password":"password123"}' 2>&1

echo ""
echo ""
echo "=== TESTING ALTERNATIVE ADMIN USERNAMES ==="

# Test john.doe (might be admin)
echo "Testing john.doe:"
curl -s -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"john.doe","password":"password123"}'

echo ""
echo "Testing admin:"
curl -s -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"password123"}'

echo ""
echo "Testing admin with different password:"
curl -s -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.admin","password":"admin123"}'

echo ""
echo ""
echo "=== CHECKING RECENT AUTHENTICATION LOGS ==="
pm2 logs servicedesk --lines 25 | grep -A 5 -B 5 "admin"

echo ""
echo "=== CREATING ADMIN USER IF MISSING ==="
psql -U servicedesk -d servicedesk -c "
INSERT INTO users (username, email, password, role, name, department, business_unit, created_at) 
VALUES ('test.admin', 'admin@company.com', 'password123', 'admin', 'Test Admin', 'IT', 'Corporate', NOW())
ON CONFLICT (username) DO UPDATE SET 
  password = 'password123',
  role = 'admin'
RETURNING id, username, email, role, name;
"

echo ""
echo "=== TESTING ADMIN LOGIN AFTER ENSURING USER EXISTS ==="
ADMIN_RESULT=$(curl -s -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.admin","password":"password123"}')

echo "Admin login result: $ADMIN_RESULT"

if echo "$ADMIN_RESULT" | grep -q '"user"'; then
    echo "SUCCESS: Admin login is now working!"
else
    echo "Admin login still failing. Result: $ADMIN_RESULT"
    echo ""
    echo "=== FINAL DATABASE CHECK ==="
    psql -U servicedesk -d servicedesk -c "SELECT * FROM users WHERE username = 'test.admin';"
fi

EOF