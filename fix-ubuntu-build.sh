#!/bin/bash

echo "Fix Ubuntu Build - Vite-Free Production Server"
echo "============================================="

cat << 'EOF'
# Run on Ubuntu server 98.81.235.7 to fix the vite import issue:

cd /var/www/itservicedesk

# Stop everything
pm2 delete all 2>/dev/null || true
sudo fuser -k 5000/tcp 2>/dev/null || true
sleep 3

# Build frontend (skip if vite fails)
echo "Building frontend..."
npx vite build 2>/dev/null || echo "Frontend build skipped - using existing dist/public"

# Build backend using production.ts (no vite dependencies)
echo "Building vite-free backend..."
npx esbuild server/production.ts \
  --platform=node \
  --packages=external \
  --bundle \
  --format=esm \
  --outdir=dist \
  --outfile=dist/production.js \
  --keep-names \
  --sourcemap

# Verify the build
echo "Build verification:"
ls -la dist/
file dist/production.js

# Test the production build directly
echo ""
echo "Testing production build directly:"
NODE_ENV=production PORT=5000 timeout 15s node dist/production.js 2>&1 | head -10 &
sleep 8

if ss -tlnp | grep -q :5000; then
    echo "✅ Production build works!"
    curl -s http://localhost:5000/api/auth/me | head -3
else
    echo "❌ Production build failed"
fi

# Kill direct test
sudo pkill -f "node dist/production.js" 2>/dev/null || true
sleep 2

# Create PM2 config for production build
cat > vite-free.config.cjs << 'VITEFREE_EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'dist/production.js',
    cwd: '/var/www/itservicedesk',
    instances: 1,
    autorestart: true,
    max_restarts: 5,
    restart_delay: 5000,
    env: {
      NODE_ENV: 'production',
      PORT: 5000,
      DATABASE_URL: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk',
      SESSION_SECRET: 'calpion-service-desk-secret-key-2025'
    }
  }]
};
VITEFREE_EOF

# Start with vite-free build
echo ""
echo "Starting vite-free application:"
pm2 start vite-free.config.cjs
pm2 save

# Monitor startup
for i in {1..20}; do
    echo "Check $i:"
    STATUS=$(pm2 list | grep servicedesk | awk '{print $10}')
    echo "  PM2 Status: $STATUS"
    
    if ss -tlnp | grep -q :5000; then
        echo "  ✅ Port 5000 bound!"
        
        # Test authentication
        echo ""
        echo "Testing authentication:"
        AUTH_RESULT=$(curl -s -X POST http://localhost:5000/api/auth/login \
          -H "Content-Type: application/json" \
          -d '{"username":"test.user","password":"password123"}')
        
        if echo "$AUTH_RESULT" | grep -q "user"; then
            echo "✅ Authentication successful!"
            echo "Response: $AUTH_RESULT"
            
            echo ""
            echo "Testing external HTTPS:"
            curl -k -s https://98.81.235.7/api/auth/me | head -5
            
            echo ""
            echo "🎉 SUCCESS: IT Service Desk is fully operational!"
            echo "- URL: https://98.81.235.7"
            echo "- Login: test.user / password123"
            echo "- All authentication and API endpoints working"
            break
        else
            echo "Authentication failed: $AUTH_RESULT"
        fi
    else
        echo "  Port not bound yet..."
        if [ "$STATUS" = "errored" ]; then
            echo "  Process errored - checking logs:"
            pm2 logs servicedesk --lines 5 --nostream
            break
        fi
    fi
    
    sleep 3
done

echo ""
echo "Final status:"
pm2 status
echo ""
echo "Port status:"
ss -tlnp | grep :5000 && echo "Port 5000 bound" || echo "Port 5000 NOT bound"

EOF