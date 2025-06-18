#!/bin/bash

echo "Deploy Working Authentication - Ubuntu Server"
echo "==========================================="

cat << 'EOF'
# Run on Ubuntu server to get authentication working:

cd /var/www/itservicedesk

echo "Checking PM2 logs for authentication errors:"
pm2 logs servicedesk --lines 20

echo ""
echo "Checking database users:"
sudo -u postgres psql -d servicedesk -c "SELECT username, password FROM users WHERE username IN ('auth.test', 'test.user', 'test.admin');"

echo ""
echo "Testing bcrypt availability:"
node -e "try { const bcrypt = require('bcrypt'); console.log('bcrypt available'); } catch(e) { console.log('bcrypt error:', e.message); }"

echo ""
echo "Restarting PM2 for fresh logs:"
pm2 restart servicedesk
sleep 10

echo ""
echo "Testing authentication:"
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"auth.test","password":"password123"}' \
  -w "\nHTTP Code: %{http_code}\n"

echo ""
echo "Current PM2 status:"
pm2 status

echo ""
echo "Recent application logs:"
pm2 logs servicedesk --lines 5

EOF