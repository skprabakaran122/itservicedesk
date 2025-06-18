#!/bin/bash

echo "Check System Status - Ubuntu Server"
echo "=================================="

cat << 'EOF'
# Run on Ubuntu server to diagnose authentication failure:

cd /var/www/itservicedesk

# Check detailed PM2 logs for authentication errors
echo "=== PM2 LOGS (Last 20 lines) ==="
pm2 logs servicedesk --lines 20

echo ""
echo "=== ERROR LOG ANALYSIS ==="
cat /tmp/servicedesk-error.log 2>/dev/null | tail -10 || echo "No error log file found"

echo ""
echo "=== DATABASE USER VERIFICATION ==="
sudo -u postgres psql -d servicedesk -c "SELECT username, email, password, role FROM users WHERE username IN ('auth.test', 'test.user', 'test.admin') ORDER BY username;"

echo ""
echo "=== BCRYPT TEST ==="
node -e "
try { 
  const bcrypt = require('bcrypt'); 
  console.log('bcrypt module loaded successfully'); 
  console.log('bcrypt version:', bcrypt.getRounds ? 'modern' : 'legacy');
} catch(e) { 
  console.log('bcrypt error:', e.message); 
}"

echo ""
echo "=== DATABASE CONNECTION TEST ==="
node -e "
const { Pool } = require('pg');
const pool = new Pool({ connectionString: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk' });
pool.query('SELECT username FROM users WHERE username = \$1', ['auth.test'])
  .then(result => {
    console.log('Database test: SUCCESS - User found:', result.rows.length > 0);
    if (result.rows.length > 0) {
      console.log('User data:', result.rows[0]);
    }
    process.exit(0);
  })
  .catch(err => {
    console.log('Database test: FAILED -', err.message);
    process.exit(1);
  });
"

echo ""
echo "=== API ENDPOINT TEST ==="
curl -s http://localhost:5000/api/auth/me | head -3

echo ""
echo "=== VERBOSE AUTHENTICATION TEST ==="
curl -v -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"auth.test","password":"password123"}' 2>&1 | head -15

echo ""
echo "=== PM2 PROCESS STATUS ==="
pm2 status

echo ""
echo "=== NODE PROCESS CHECK ==="
ps aux | grep "node.*production.js" | grep -v grep || echo "No production node process found"

EOF