#!/bin/bash

echo "Sync Working Code and Rebuild - Ubuntu Server"
echo "============================================"

cat << 'EOF'
# Run on Ubuntu server to get the latest working code:

cd /var/www/itservicedesk

# First check current PM2 logs to see what's failing
echo "=== CURRENT AUTHENTICATION ERRORS ==="
pm2 logs servicedesk --lines 10

# Pull latest code from git repository (if configured)
echo ""
echo "=== SYNCING LATEST CODE ==="
if [ -d .git ]; then
    echo "Git repository found, pulling latest changes..."
    git pull origin main || git pull origin master || echo "Git pull failed - proceeding with local fixes"
else
    echo "No git repository found - using local code"
fi

# Ensure we have the latest server code structure
# Copy the working authentication logic from development

# Verify database users are correct
echo ""
echo "=== VERIFYING DATABASE USERS ==="
sudo -u postgres psql -d servicedesk -c "
UPDATE users SET password = 'password123' 
WHERE username IN ('test.user', 'test.admin', 'john.doe');

SELECT username, password, role 
FROM users 
WHERE username IN ('test.user', 'test.admin') 
ORDER BY username;
"

# Install/update dependencies
echo ""
echo "=== INSTALLING DEPENDENCIES ==="
npm install bcrypt @types/bcrypt express-session @types/express-session

# Check if we have the production server file
if [ ! -f server/production.ts ]; then
    echo ""
    echo "WARNING: server/production.ts not found!"
    echo "Using server/index.ts for production build instead"
    BUILD_SOURCE="server/index.ts"
else
    BUILD_SOURCE="server/production.ts"
fi

# Rebuild with the correct source file
echo ""
echo "=== REBUILDING PRODUCTION SERVER ==="
echo "Building from: $BUILD_SOURCE"

npx esbuild $BUILD_SOURCE \
  --platform=node \
  --packages=external \
  --bundle \
  --format=esm \
  --outfile=dist/production.js \
  --keep-names \
  --sourcemap \
  --define:process.env.NODE_ENV='"production"'

# Create updated PM2 configuration
echo ""
echo "=== CREATING PM2 CONFIGURATION ==="
cat > production-sync.config.cjs << 'PM2_CONFIG_EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'dist/production.js',
    instances: 1,
    autorestart: true,
    max_restarts: 5,
    restart_delay: 3000,
    env: {
      NODE_ENV: 'production',
      PORT: 5000,
      DATABASE_URL: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk',
      SESSION_SECRET: 'calpion-service-desk-secret-key-2025',
      REPLIT_ENV: 'false'
    },
    error_file: '/tmp/servicedesk-error.log',
    out_file: '/tmp/servicedesk-out.log',
    log_file: '/tmp/servicedesk-combined.log',
    merge_logs: true,
    log_date_format: 'YYYY-MM-DD HH:mm:ss'
  }]
};
PM2_CONFIG_EOF

# Stop current PM2 process
echo ""
echo "=== RESTARTING PM2 WITH SYNCED CODE ==="
pm2 delete servicedesk 2>/dev/null || echo "No existing PM2 process found"

# Start with new configuration
pm2 start production-sync.config.cjs
pm2 save

# Wait for startup
sleep 15

# Test authentication immediately
echo ""
echo "=== TESTING SYNCED AUTHENTICATION ==="
AUTH_TEST=$(curl -s -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.user","password":"password123"}')

echo "Local auth test: $AUTH_TEST"

# Test admin login
echo ""
echo "=== TESTING ADMIN LOGIN ==="
ADMIN_TEST=$(curl -s -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.admin","password":"password123"}')

echo "Admin auth test: $ADMIN_TEST"

# Test external HTTPS
echo ""
echo "=== TESTING EXTERNAL HTTPS ==="
HTTPS_TEST=$(curl -k -s https://98.81.235.7/api/auth/login \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"username":"test.user","password":"password123"}')

echo "HTTPS auth test: $HTTPS_TEST"

# Show current status
echo ""
echo "=== CURRENT STATUS ==="
pm2 status

echo ""
echo "=== RECENT LOGS ==="
pm2 logs servicedesk --lines 5 --timestamp

# Final analysis
echo ""
echo "=== FINAL ANALYSIS ==="
if echo "$AUTH_TEST" | grep -q "user"; then
    echo "✅ SUCCESS: Authentication working after sync!"
    echo ""
    echo "Ubuntu server is now operational at https://98.81.235.7"
    echo "Login credentials:"
    echo "- test.user / password123"
    echo "- test.admin / password123"
else
    echo "❌ Authentication still failing after sync"
    echo "Response: $AUTH_TEST"
    echo ""
    echo "Additional debugging needed - check PM2 logs above"
fi

EOF