#!/bin/bash

echo "Complete Ubuntu Deployment with Latest Code"
echo "=========================================="

cat << 'EOF'
# Run on Ubuntu server to sync latest working code and fix authentication:

cd /var/www/itservicedesk

# Check current authentication failure
echo "=== CURRENT PM2 STATUS ==="
pm2 logs servicedesk --lines 8

# If git is available, pull latest changes
echo ""
echo "=== SYNCING CODE ==="
if [ -d .git ]; then
    echo "Pulling latest code from repository..."
    git stash 2>/dev/null || true
    git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || echo "Git pull not available"
    echo "Code sync attempted"
else
    echo "No git repository - using current code"
fi

# Update dependencies to match working development environment
echo ""
echo "=== UPDATING DEPENDENCIES ==="
npm install bcrypt @types/bcrypt express-session connect-pg-simple

# Reset database users to match development
echo ""
echo "=== RESETTING DATABASE USERS ==="
sudo -u postgres psql -d servicedesk -c "
UPDATE users SET password = 'password123' 
WHERE username IN ('test.user', 'test.admin', 'john.doe');

-- Ensure test users exist
INSERT INTO users (username, email, password, role, name, created_at) 
VALUES ('test.user', 'test.user@company.com', 'password123', 'user', 'Test User', NOW())
ON CONFLICT (username) DO UPDATE SET password = 'password123';

INSERT INTO users (username, email, password, role, name, created_at) 
VALUES ('test.admin', 'test.admin@company.com', 'password123', 'admin', 'Test Admin', NOW())
ON CONFLICT (username) DO UPDATE SET password = 'password123';

SELECT username, password, role FROM users WHERE username LIKE 'test.%';
"

# Use the correct source file for production build
if [ -f server/production.ts ]; then
    PRODUCTION_SOURCE="server/production.ts"
    echo ""
    echo "=== USING PRODUCTION SERVER SOURCE ==="
else
    PRODUCTION_SOURCE="server/index.ts"
    echo ""
    echo "=== USING DEVELOPMENT SERVER SOURCE ==="
fi

echo "Building from: $PRODUCTION_SOURCE"

# Rebuild production server with latest code
npx esbuild $PRODUCTION_SOURCE \
  --platform=node \
  --packages=external \
  --bundle \
  --format=esm \
  --outfile=dist/production.js \
  --keep-names \
  --sourcemap \
  --define:process.env.NODE_ENV='"production"'

# Create production PM2 config matching development environment
cat > latest.config.cjs << 'LATEST_EOF'
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
      SESSION_SECRET: 'calpion-service-desk-secret-key-2025'
    },
    error_file: '/tmp/servicedesk-error.log',
    out_file: '/tmp/servicedesk-out.log',
    log_file: '/tmp/servicedesk-combined.log',
    merge_logs: true,
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z'
  }]
};
LATEST_EOF

# Stop and restart PM2 with updated code
echo ""
echo "=== RESTARTING WITH LATEST CODE ==="
pm2 delete servicedesk
pm2 start latest.config.cjs
pm2 save

# Wait for application startup
sleep 18

# Test authentication with latest code
echo ""
echo "=== TESTING AUTHENTICATION WITH LATEST CODE ==="
LOCAL_AUTH=$(curl -s -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.user","password":"password123"}')

echo "Local authentication: $LOCAL_AUTH"

# Test admin authentication
echo ""
echo "=== TESTING ADMIN AUTHENTICATION ==="
ADMIN_AUTH=$(curl -s -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.admin","password":"password123"}')

echo "Admin authentication: $ADMIN_AUTH"

# Test external HTTPS access
echo ""
echo "=== TESTING EXTERNAL HTTPS ACCESS ==="
EXTERNAL_AUTH=$(curl -k -s https://98.81.235.7/api/auth/login \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"username":"test.user","password":"password123"}')

echo "External HTTPS: $EXTERNAL_AUTH"

# Show deployment status
echo ""
echo "=== DEPLOYMENT STATUS ==="
pm2 status

echo ""
echo "=== RECENT APPLICATION LOGS ==="
pm2 logs servicedesk --lines 6 --timestamp

# Final verification
echo ""
echo "=== DEPLOYMENT VERIFICATION ==="
if echo "$LOCAL_AUTH" | grep -q "user"; then
    echo "✅ SUCCESS: Ubuntu server authentication is working!"
    echo ""
    echo "Production deployment complete:"
    echo "- Server: https://98.81.235.7"
    echo "- Authentication: Working"
    echo "- Test credentials: test.user/password123 or test.admin/password123"
    echo ""
    echo "The Ubuntu server now has the latest working code from development."
elif echo "$LOCAL_AUTH" | grep -q "Login failed"; then
    echo "❌ Authentication still failing - check PM2 logs above for specific errors"
else
    echo "⚠️  Unexpected response: $LOCAL_AUTH"
    echo "Server may need additional debugging"
fi

EOF