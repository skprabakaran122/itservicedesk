#!/bin/bash

echo "Fix Admin User in Ubuntu Database"
echo "================================"

cat << 'EOF'
# Fix the missing admin user in Ubuntu production database:

cd /var/www/itservicedesk

echo "=== CHECKING CURRENT USERS IN UBUNTU DATABASE ==="
psql -U servicedesk -d servicedesk -c "SELECT id, username, email, password, role, name FROM users ORDER BY id;"

echo ""
echo "=== CREATING/UPDATING ADMIN USER ==="
psql -U servicedesk -d servicedesk -c "
INSERT INTO users (username, email, password, role, name, department, business_unit, created_at) 
VALUES ('test.admin', 'test.admin@company.com', 'password123', 'admin', 'Test Admin', 'IT', 'Corporate', NOW())
ON CONFLICT (username) DO UPDATE SET 
  password = 'password123',
  role = 'admin',
  email = 'test.admin@company.com',
  name = 'Test Admin'
RETURNING id, username, email, role, name;
"

echo ""
echo "=== VERIFYING ADMIN USER EXISTS ==="
psql -U servicedesk -d servicedesk -c "SELECT id, username, email, password, role, name FROM users WHERE username = 'test.admin';"

echo ""
echo "=== TESTING ADMIN LOGIN ==="
ADMIN_LOGIN_RESULT=$(curl -s -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.admin","password":"password123"}')

echo "Admin login result: $ADMIN_LOGIN_RESULT"

echo ""
echo "=== TESTING EXTERNAL HTTPS ADMIN LOGIN ==="
HTTPS_ADMIN_RESULT=$(curl -k -s https://98.81.235.7/api/auth/login \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"username":"test.admin","password":"password123"}')

echo "HTTPS admin login result: $HTTPS_ADMIN_RESULT"

echo ""
echo "=== CHECKING AUTHENTICATION LOGS ==="
pm2 logs servicedesk --lines 10 | grep -A 3 -B 3 "test.admin"

echo ""
echo "=== FINAL VERIFICATION ==="
if echo "$ADMIN_LOGIN_RESULT" | grep -q '"user"'; then
    echo "SUCCESS: Admin login is now working!"
    echo ""
    echo "Admin credentials:"
    echo "- Username: test.admin"
    echo "- Password: password123"
    echo "- Role: admin"
    echo ""
    echo "You can now log in to https://98.81.235.7 with admin access!"
else
    echo "Admin login still not working. Checking what went wrong..."
    echo "Admin result: $ADMIN_LOGIN_RESULT"
    echo ""
    echo "Current users in database:"
    psql -U servicedesk -d servicedesk -c "SELECT username, role FROM users;"
fi

EOF