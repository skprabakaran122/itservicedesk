#!/bin/bash

echo "Debug Ubuntu User Management Issues"
echo "=================================="

cat << 'EOF'
# Debug user management issues on Ubuntu server:

cd /var/www/itservicedesk

echo "=== TESTING test.admin AUTHENTICATION ==="
TEST_ADMIN_RESULT=$(curl -s -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.admin","password":"password123"}')

echo "test.admin login result:"
echo "$TEST_ADMIN_RESULT"

echo ""
echo "=== TESTING USER API ENDPOINT ==="
USERS_API_RESULT=$(curl -s http://localhost:5000/api/users)
echo "Users API result:"
echo "$USERS_API_RESULT" | jq . 2>/dev/null || echo "$USERS_API_RESULT"

echo ""
echo "=== CHECKING DATABASE USERS ==="
psql -U servicedesk -d servicedesk -c "SELECT id, username, email, password, role, name FROM users ORDER BY id;"

echo ""
echo "=== TESTING USER CREATION API ==="
# Test creating a new user
CREATE_USER_RESULT=$(curl -s -X POST http://localhost:5000/api/users \
  -H "Content-Type: application/json" \
  -d '{
    "username": "test.newuser",
    "email": "test.newuser@company.com",
    "password": "password123",
    "role": "user",
    "name": "Test New User"
  }')

echo "User creation result:"
echo "$CREATE_USER_RESULT"

echo ""
echo "=== CHECKING PM2 LOGS FOR ERRORS ==="
pm2 logs servicedesk --lines 20 | grep -i -A 3 -B 3 "error\|fail\|users"

echo ""
echo "=== TESTING AUTHENTICATED USER API ACCESS ==="
# First login with john.doe
LOGIN_RESULT=$(curl -s -c /tmp/cookies.txt -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"john.doe","password":"password123"}')

echo "Login result for john.doe:"
echo "$LOGIN_RESULT"

# Then try accessing users API with session
AUTHENTICATED_USERS_RESULT=$(curl -s -b /tmp/cookies.txt http://localhost:5000/api/users)
echo ""
echo "Authenticated users API result:"
echo "$AUTHENTICATED_USERS_RESULT" | jq . 2>/dev/null || echo "$AUTHENTICATED_USERS_RESULT"

echo ""
echo "=== CHECKING CURRENT SERVER ROUTES ==="
echo "Available routes in current server:"
grep -n "app\." /var/www/itservicedesk/*.cjs | head -20

echo ""
echo "=== VERIFICATION SUMMARY ==="
if echo "$TEST_ADMIN_RESULT" | grep -q '"user"'; then
    echo "✓ test.admin authentication: WORKING"
else
    echo "✗ test.admin authentication: FAILED"
    echo "Result: $TEST_ADMIN_RESULT"
fi

if echo "$USERS_API_RESULT" | grep -q '"username"'; then
    echo "✓ Users API endpoint: WORKING"
    USER_COUNT=$(echo "$USERS_API_RESULT" | grep -o '"username"' | wc -l)
    echo "  - Returned $USER_COUNT users"
else
    echo "✗ Users API endpoint: FAILED"
    echo "Result: $USERS_API_RESULT"
fi

if echo "$CREATE_USER_RESULT" | grep -q '"id"'; then
    echo "✓ User creation API: WORKING"
else
    echo "✗ User creation API: FAILED"
    echo "Result: $CREATE_USER_RESULT"
fi

# Clean up
rm -f /tmp/cookies.txt

EOF