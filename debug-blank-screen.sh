#!/bin/bash

# Debug the blank screen after login issue
cd /var/www/itservicedesk

echo "=== Debugging Blank Screen After Login ==="

echo "1. Checking current HTML content being served..."
curl -s http://localhost:5000/ > /tmp/current_html.html
echo "HTML file size: $(wc -c < /tmp/current_html.html) bytes"
cat /tmp/current_html.html

echo ""
echo "2. Checking if assets exist and are accessible..."
echo "CSS file:"
curl -s -I http://localhost:5000/assets/index-Cf-nQCTa.css | head -3

echo "JS file:"
curl -s -I http://localhost:5000/assets/index-u5OElkvU.js | head -3

echo ""
echo "3. Testing authentication flow step by step..."
# Login and get cookie
LOGIN_COOKIE=$(curl -s -c - -X POST http://localhost:5000/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"username":"admin","password":"password123"}' | grep connect.sid | cut -f7)

echo "Login cookie: $LOGIN_COOKIE"

# Test session persistence
SESSION_TEST=$(curl -s -H "Cookie: connect.sid=$LOGIN_COOKIE" http://localhost:5000/api/auth/me)
echo "Session test: $SESSION_TEST"

echo ""
echo "4. Checking what happens when accessing root after login..."
ROOT_AFTER_LOGIN=$(curl -s -H "Cookie: connect.sid=$LOGIN_COOKIE" http://localhost:5000/ | head -20)
echo "$ROOT_AFTER_LOGIN"

echo ""
echo "5. Checking PM2 logs for any client-side errors..."
pm2 logs itservicedesk --lines 5

echo ""
echo "6. Checking file structure in dist/public..."
ls -la dist/public/

echo ""
echo "7. Testing direct asset access..."
if [ -f "dist/public/assets/index-u5OElkvU.js" ]; then
    echo "JS file exists, checking first few lines..."
    head -5 dist/public/assets/index-u5OElkvU.js
else
    echo "JS file missing!"
fi

echo ""
echo "=== Debug Complete ==="