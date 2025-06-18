#!/bin/bash

echo "Quick Ubuntu Authentication Fix"
echo "=============================="

cat << 'EOF'
# Run on Ubuntu server to fix authentication:

cd /var/www/itservicedesk

# Check PM2 logs for authentication errors
echo "PM2 logs for authentication errors:"
pm2 logs servicedesk --lines 15

# Verify users in database
echo ""
echo "Database users:"
sudo -u postgres psql -d servicedesk -c "SELECT username, password FROM users WHERE username LIKE 'test.%' OR username = 'auth.test';"

# Test bcrypt availability
echo ""
echo "Testing bcrypt:"
node -e "try { const bcrypt = require('bcrypt'); console.log('✅ bcrypt available'); } catch(e) { console.log('❌ bcrypt error:', e.message); }"

# Restart with detailed logging
pm2 restart servicedesk --update-env
sleep 10

# Test authentication with verbose output
echo ""
echo "Testing authentication with verbose output:"
curl -v -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"auth.test","password":"password123"}' 2>&1 | head -20

EOF