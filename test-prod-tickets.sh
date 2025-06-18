#!/bin/bash

echo "Testing production tickets API and frontend..."

# Test if production server is responding
echo "=== Testing production server health ==="
curl -s https://98.81.235.7/health | head -50

echo -e "\n=== Testing authentication ==="
JOHN_AUTH=$(curl -s -c /tmp/prod_cookies.txt -X POST https://98.81.235.7/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"john.doe","password":"password123"}' -k)
echo "$JOHN_AUTH"

echo -e "\n=== Testing tickets API ==="
TICKETS_RESULT=$(curl -s -b /tmp/prod_cookies.txt https://98.81.235.7/api/tickets -k)
echo "Tickets API response:"
echo "$TICKETS_RESULT" | head -200

echo -e "\n=== Testing products API ==="
PRODUCTS_RESULT=$(curl -s -b /tmp/prod_cookies.txt https://98.81.235.7/api/products -k)
echo "Products API response:"
echo "$PRODUCTS_RESULT" | head -200

echo -e "\n=== Testing frontend access ==="
FRONTEND_TEST=$(curl -s -I https://98.81.235.7/ -k | head -5)
echo "Frontend headers:"
echo "$FRONTEND_TEST"

echo -e "\n=== Testing dashboard route specifically ==="
DASHBOARD_TEST=$(curl -s https://98.81.235.7/dashboard -k | head -100)
echo "Dashboard page:"
echo "$DASHBOARD_TEST"

rm -f /tmp/prod_cookies.txt

echo -e "\n=== Checking if there are JavaScript errors in the build ==="
curl -s https://98.81.235.7/ -k | grep -o 'src="[^"]*\.js"' | head -5
