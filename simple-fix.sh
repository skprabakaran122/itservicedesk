#!/bin/bash

echo "Simple Test and Fix - Ubuntu Server"
echo "================================="

cat << 'EOF'
# Test current working state on Ubuntu server:

cd /var/www/itservicedesk

# Test if application is responding
echo "Testing application on port 5000..."
curl -s http://localhost:5000/api/auth/me | head -5

echo ""
echo "Testing authentication..."
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.user","password":"password123"}' \
  -s | head -5

echo ""
echo "Testing external HTTPS..."
curl -k -s https://98.81.235.7/api/auth/me | head -5

echo ""
echo "Check PM2 logs for any errors..."
pm2 logs servicedesk --lines 5

# If authentication still fails, rebuild with the latest code
if ! curl -s http://localhost:5000/api/auth/login -X POST -H "Content-Type: application/json" -d '{"username":"test.user","password":"password123"}' | grep -q "user"; then
    echo "Authentication issue detected. Rebuilding with latest fixes..."
    
    # Sync the latest code changes
    git pull 2>/dev/null || echo "No git sync available"
    
    # Rebuild backend with the authentication fixes
    npx esbuild server/index.ts \
      --platform=node \
      --packages=external \
      --bundle \
      --format=esm \
      --outdir=dist \
      --external:vite
    
    # Restart PM2
    pm2 restart servicedesk
    
    # Wait and test again
    sleep 10
    echo "Testing after rebuild..."
    curl -X POST http://localhost:5000/api/auth/login \
      -H "Content-Type: application/json" \
      -d '{"username":"test.user","password":"password123"}' \
      -s | head -5
fi

echo ""
echo "Final status:"
pm2 status

EOF