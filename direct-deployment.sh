#!/bin/bash

echo "Direct Deployment - Working Authentication System"
echo "==============================================="

cat << 'EOF'
# Deploy working authentication system to Ubuntu server:

cd /var/www/itservicedesk

# Clean shutdown
pm2 delete all 2>/dev/null || true
sudo fuser -k 5000/tcp 2>/dev/null || true
sleep 5

# Check PM2 logs for any startup errors
echo "Checking previous logs..."
pm2 logs --lines 10 2>/dev/null || echo "No previous logs"

# Rebuild with the authentication fixes
echo "Building with authentication fixes..."
npx esbuild server/index.ts \
  --platform=node \
  --packages=external \
  --bundle \
  --format=esm \
  --outdir=dist \
  --external:vite \
  --sourcemap \
  --keep-names

# Create final PM2 configuration
cat > final.config.cjs << 'FINAL_EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'dist/index.js',
    instances: 1,
    autorestart: true,
    max_restarts: 5,
    restart_delay: 3000,
    env: {
      NODE_ENV: 'production',
      PORT: 5000,
      DATABASE_URL: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk',
      SESSION_SECRET: 'calpion-service-desk-secret-key-2025'
    }
  }]
};
FINAL_EOF

# Start application
pm2 start final.config.cjs
pm2 save

# Wait for proper startup
echo "Waiting for application startup..."
sleep 15

# Test port binding
echo "Checking port 5000..."
ss -tlnp | grep :5000 || netstat -tlnp | grep :5000

# Test application response
echo "Testing application response..."
curl -s http://localhost:5000/api/auth/me | head -5

# Test authentication with correct credentials
echo "Testing authentication..."
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.user","password":"password123"}' \
  -s | head -10

# Test external HTTPS access
echo "Testing external HTTPS access..."
curl -k -s https://98.81.235.7/api/auth/me | head -5

# Show final status
echo "Final PM2 status:"
pm2 status

echo "Application logs:"
pm2 logs servicedesk --lines 5

echo ""
echo "SUCCESS INDICATORS:"
echo "- PM2 status should show 'online'"
echo "- Port 5000 should be bound" 
echo "- Authentication should return user data"
echo "- External HTTPS should work"

EOF