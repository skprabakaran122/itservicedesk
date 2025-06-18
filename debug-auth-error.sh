#!/bin/bash

echo "Debug Authentication Error - Ubuntu Server"
echo "========================================"

cat << 'EOF'
# Debug authentication failure on Ubuntu server:

cd /var/www/itservicedesk

# Check detailed PM2 logs for authentication errors
echo "Detailed PM2 logs:"
pm2 logs servicedesk --lines 20

# Check error logs specifically
echo ""
echo "Error logs:"
cat /tmp/servicedesk-error.log 2>/dev/null | tail -10 || echo "No error log found"

# Verify database connectivity and user data
echo ""
echo "Database user verification:"
sudo -u postgres psql -d servicedesk -c "
SELECT username, email, password, role, created_at 
FROM users 
WHERE username IN ('auth.test', 'test.user', 'test.admin') 
ORDER BY username;
"

# Test database connectivity from Node.js perspective
echo ""
echo "Testing database connection directly:"
node -e "
const { Pool } = require('pg');
const pool = new Pool({ connectionString: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk' });
pool.query('SELECT COUNT(*) FROM users').then(result => {
  console.log('Database test successful:', result.rows[0]);
  process.exit(0);
}).catch(err => {
  console.error('Database test failed:', err.message);
  process.exit(1);
});
"

# Test a simple API endpoint to see if the server is responding
echo ""
echo "Testing basic API response:"
curl -s http://localhost:5000/api/auth/me | head -5

# Test with verbose curl to see full request/response
echo ""
echo "Verbose authentication test:"
curl -v -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"auth.test","password":"password123"}' 2>&1 | head -15

EOF