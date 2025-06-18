#!/bin/bash

echo "Fix Frontend Authentication - Ubuntu Server"
echo "========================================="

cat << 'EOF'
# Complete authentication debugging and fix:

cd /var/www/itservicedesk

# Check PM2 logs for specific authentication errors
echo "PM2 authentication logs:"
pm2 logs servicedesk --lines 15 | grep -A5 -B5 "auth\|login\|Login" || pm2 logs servicedesk --lines 10

# Check if bcrypt is properly loaded
echo ""
echo "Testing bcrypt availability:"
node -e "try { const bcrypt = require('bcrypt'); console.log('bcrypt available'); } catch(e) { console.log('bcrypt error:', e.message); }"

# Verify user exists and test direct database query
echo ""
echo "Direct database authentication test:"
sudo -u postgres psql -d servicedesk -c "
SELECT username, password, role 
FROM users 
WHERE username = 'auth.test' AND password = 'password123';
"

# Create a simple test script to debug authentication
cat > test-auth.js << 'AUTH_TEST_EOF'
const { Pool } = require('pg');

async function testAuth() {
  const pool = new Pool({ 
    connectionString: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk' 
  });
  
  try {
    // Test database connection
    const result = await pool.query('SELECT username, password FROM users WHERE username = $1', ['auth.test']);
    console.log('User found:', result.rows[0]);
    
    if (result.rows.length > 0) {
      const user = result.rows[0];
      console.log('Password match test:', user.password === 'password123');
    }
    
  } catch (error) {
    console.error('Database error:', error.message);
  } finally {
    await pool.end();
  }
}

testAuth();
AUTH_TEST_EOF

echo ""
echo "Running authentication test:"
node test-auth.js

# Test the API directly with minimal request
echo ""
echo "Testing API with minimal request:"
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"auth.test","password":"password123"}' \
  -w "\nResponse Code: %{http_code}\n" \
  -s

# Check if session middleware is working
echo ""
echo "Testing session endpoint:"
curl -s http://localhost:5000/api/auth/me

# Rebuild with additional debugging
echo ""
echo "Rebuilding with error handling:"
npx esbuild server/production.ts \
  --platform=node \
  --packages=external \
  --bundle \
  --format=esm \
  --outfile=dist/production.js \
  --keep-names \
  --sourcemap

pm2 restart servicedesk
sleep 8

# Final authentication test
echo ""
echo "Final authentication test after rebuild:"
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"auth.test","password":"password123"}' \
  -s | head -10

echo ""
echo "Testing external HTTPS:"
curl -k https://98.81.235.7/api/auth/login \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"username":"auth.test","password":"password123"}' \
  -s | head -10

# Clean up test file
rm -f test-auth.js

EOF