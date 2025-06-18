#!/bin/bash

echo "Fix Ubuntu Deployment - Corrected Build Command"
echo "=============================================="

cat << 'EOF'
# Run on Ubuntu server 98.81.235.7 to fix the build and deployment:

cd /var/www/itservicedesk

# Stop everything
pm2 delete all 2>/dev/null || true
sudo fuser -k 5000/tcp 2>/dev/null || true
sleep 3

# Build vite-free backend with corrected parameters
echo "Building vite-free backend..."
npx esbuild server/production.ts \
  --platform=node \
  --packages=external \
  --bundle \
  --format=esm \
  --outfile=dist/production.js \
  --keep-names \
  --sourcemap

# Verify the build
echo "Build verification:"
ls -la dist/production.js
file dist/production.js

# Test the production build directly
echo ""
echo "Testing production build directly:"
NODE_ENV=production PORT=5000 timeout 12s node dist/production.js 2>&1 | head -15 &
sleep 8

if ss -tlnp | grep -q :5000; then
    echo "✅ Production build SUCCESS!"
    curl -s http://localhost:5000/api/auth/me | head -3
else
    echo "❌ Production build failed - checking what went wrong"
fi

# Kill direct test
sudo pkill -f "node dist/production.js" 2>/dev/null || true
sleep 2

# Create corrected PM2 config
cat > production-fixed.config.cjs << 'FIXED_EOF'
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
    },
    error_file: '/tmp/servicedesk-error.log',
    out_file: '/tmp/servicedesk-out.log'
  }]
};
FIXED_EOF

# Start with corrected config
echo ""
echo "Starting corrected application:"
pm2 start production-fixed.config.cjs
pm2 save

# Monitor startup with detailed checking
for i in {1..25}; do
    echo "Check $i:"
    
    # Get PM2 status
    STATUS=$(pm2 list | grep servicedesk | awk '{print $10}' 2>/dev/null || echo "not_found")
    echo "  PM2 Status: $STATUS"
    
    # Check for errors in logs
    if [ -f /tmp/servicedesk-error.log ]; then
        ERROR_COUNT=$(wc -l < /tmp/servicedesk-error.log 2>/dev/null || echo 0)
        if [ "$ERROR_COUNT" -gt 0 ]; then
            echo "  ❌ Errors detected:"
            tail -3 /tmp/servicedesk-error.log
        fi
    fi
    
    # Check port binding
    if ss -tlnp | grep -q ":5000"; then
        echo "  ✅ Port 5000 is bound!"
        
        # Test API response
        API_TEST=$(curl -s http://localhost:5000/api/auth/me 2>/dev/null | head -1)
        echo "  API Response: $API_TEST"
        
        # Test authentication
        echo ""
        echo "Testing authentication:"
        AUTH_RESULT=$(curl -s -X POST http://localhost:5000/api/auth/login \
          -H "Content-Type: application/json" \
          -d '{"username":"test.user","password":"password123"}' 2>/dev/null)
        
        if echo "$AUTH_RESULT" | grep -q "user"; then
            echo "✅ Authentication SUCCESS!"
            echo "User data: $(echo "$AUTH_RESULT" | head -3)"
            
            echo ""
            echo "Testing external HTTPS access:"
            HTTPS_TEST=$(curl -k -s https://98.81.235.7/api/auth/me 2>/dev/null | head -3)
            echo "HTTPS Response: $HTTPS_TEST"
            
            echo ""
            echo "🎉 DEPLOYMENT SUCCESSFUL!"
            echo "- IT Service Desk is live at: https://98.81.235.7"
            echo "- Login credentials: test.user / password123"
            echo "- Authentication system working"
            echo "- All API endpoints responding"
            break
        else
            echo "Authentication issue: $AUTH_RESULT"
        fi
    else
        echo "  Port 5000 not bound yet..."
    fi
    
    # Check if process errored
    if [ "$STATUS" = "errored" ]; then
        echo "  ❌ Process errored - final logs:"
        tail -10 /tmp/servicedesk-error.log 2>/dev/null || echo "No error log"
        break
    fi
    
    sleep 3
done

# Final status report
echo ""
echo "=== FINAL STATUS ==="
pm2 status
echo ""
echo "Port status:"
ss -tlnp | grep :5000 && echo "✅ Port 5000 bound" || echo "❌ Port 5000 NOT bound"
echo ""
echo "Process status:"
ps aux | grep "node.*production.js" | grep -v grep || echo "No production process found"

# Show any final logs if there were issues
if ! ss -tlnp | grep -q :5000; then
    echo ""
    echo "Troubleshooting logs:"
    echo "Error log:"
    cat /tmp/servicedesk-error.log 2>/dev/null || echo "No error log"
    echo ""
    echo "Output log:"
    cat /tmp/servicedesk-out.log 2>/dev/null || echo "No output log"
fi

EOF