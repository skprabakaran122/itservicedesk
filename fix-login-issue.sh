#!/bin/bash

echo "Fix Login Issue - Ubuntu Server"
echo "=============================="

cat << 'EOF'
# Critical fix for Ubuntu server - address the core application startup issue:

cd /var/www/itservicedesk

# Stop all processes and check logs first
pm2 delete all 2>/dev/null || true
sudo fuser -k 5000/tcp 2>/dev/null || true

# Check previous error logs to understand what's failing
echo "=== PREVIOUS ERROR ANALYSIS ==="
cat /home/ubuntu/.pm2/logs/servicedesk-error-0.log 2>/dev/null | tail -20 || echo "No error logs found"

# Test database connectivity first
echo ""
echo "=== DATABASE CONNECTIVITY TEST ==="
sudo -u postgres psql -d servicedesk -c "\dt" 2>/dev/null && echo "✅ Database accessible" || echo "❌ Database connection failed"

# Test if the built file has the basic structure
echo ""
echo "=== BUILD FILE ANALYSIS ==="
if [ -f dist/index.js ]; then
    echo "Build file exists: $(ls -lh dist/index.js)"
    echo "First 5 lines of built file:"
    head -5 dist/index.js
    echo "Checking for import issues:"
    grep -n "import.*vite" dist/index.js || echo "No problematic vite imports found"
else
    echo "❌ dist/index.js not found - rebuild needed"
fi

# Rebuild with proper production settings
echo ""
echo "=== PRODUCTION REBUILD ==="
npx esbuild server/index.ts \
  --platform=node \
  --packages=external \
  --bundle \
  --format=esm \
  --outdir=dist \
  --external:vite \
  --external:@vitejs/plugin-react \
  --external:node_modules \
  --define:process.env.NODE_ENV=\"production\" \
  --log-level=warning

# Test the rebuilt file directly
echo ""
echo "=== DIRECT NODE TEST ==="
NODE_ENV=production PORT=5000 timeout 15s node dist/index.js 2>&1 | head -20 &
DIRECT_PID=$!
sleep 10

# Check if direct execution worked
if ss -tlnp | grep -q :5000; then
    echo "✅ Direct execution SUCCESS - port 5000 bound"
    # Test authentication quickly
    curl -s http://localhost:5000/api/auth/me | head -3
else
    echo "❌ Direct execution FAILED - checking what went wrong"
    wait $DIRECT_PID
fi

# Kill direct test
sudo pkill -f "node dist/index.js" 2>/dev/null || true
sleep 2

# Create bulletproof PM2 configuration
echo ""
echo "=== CREATING BULLETPROOF PM2 CONFIG ==="
cat > bulletproof.config.cjs << 'BULLETPROOF_EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'dist/index.js',
    cwd: '/var/www/itservicedesk',
    instances: 1,
    autorestart: true,
    max_restarts: 5,
    min_uptime: '30s',
    restart_delay: 10000,
    kill_timeout: 5000,
    env: {
      NODE_ENV: 'production',
      PORT: '5000',
      DATABASE_URL: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk',
      SESSION_SECRET: 'calpion-service-desk-secret-key-2025'
    },
    error_file: '/tmp/servicedesk-error.log',
    out_file: '/tmp/servicedesk-out.log',
    pid_file: '/tmp/servicedesk.pid',
    exec_mode: 'fork',
    watch: false,
    ignore_watch: ['node_modules', 'logs', '.git']
  }]
};
BULLETPROOF_EOF

# Start with bulletproof config
echo ""
echo "=== STARTING WITH BULLETPROOF CONFIG ==="
pm2 start bulletproof.config.cjs
pm2 save

# Monitor startup with detailed logging
echo ""
echo "=== STARTUP MONITORING ==="
for i in {1..25}; do
    echo "Check $i/25:"
    
    # PM2 status
    STATUS=$(pm2 list | grep servicedesk | awk '{print $10}' 2>/dev/null || echo "not_found")
    echo "  PM2 Status: $STATUS"
    
    # Check for errors
    if [ -f /tmp/servicedesk-error.log ]; then
        ERRORS=$(tail -3 /tmp/servicedesk-error.log 2>/dev/null | grep -v "^$" | wc -l)
        if [ $ERRORS -gt 0 ]; then
            echo "  ❌ ERRORS DETECTED:"
            tail -3 /tmp/servicedesk-error.log
        fi
    fi
    
    # Check port binding
    if ss -tlnp | grep -q ":5000"; then
        echo "  ✅ Port 5000 BOUND - Application ready!"
        
        # Quick authentication test
        echo ""
        echo "=== AUTHENTICATION TEST ==="
        AUTH_RESULT=$(curl -s -X POST http://localhost:5000/api/auth/login \
          -H "Content-Type: application/json" \
          -d '{"username":"test.user","password":"password123"}' | head -3)
        echo "Auth test result: $AUTH_RESULT"
        
        # External HTTPS test
        echo ""
        echo "=== EXTERNAL HTTPS TEST ==="
        HTTPS_RESULT=$(curl -k -s https://98.81.235.7/api/auth/me | head -3)
        echo "HTTPS test result: $HTTPS_RESULT"
        
        break
    else
        echo "  Port 5000 not bound yet..."
    fi
    
    if [ "$STATUS" = "errored" ]; then
        echo "  ❌ Process errored - stopping monitoring"
        echo "  Final error log:"
        tail -10 /tmp/servicedesk-error.log 2>/dev/null || echo "No error log"
        break
    fi
    
    sleep 3
done

# Final status report
echo ""
echo "=== FINAL STATUS REPORT ==="
pm2 status
echo ""
echo "Port status:"
ss -tlnp | grep :5000 || echo "Port 5000 NOT bound"
echo ""
echo "Process check:"
ps aux | grep "node.*dist/index.js" | grep -v grep || echo "No node process found"

# Output logs for debugging if needed
echo ""
echo "=== ERROR LOG (last 10 lines) ==="
tail -10 /tmp/servicedesk-error.log 2>/dev/null || echo "No error log"
echo ""
echo "=== OUTPUT LOG (last 5 lines) ==="
tail -5 /tmp/servicedesk-out.log 2>/dev/null || echo "No output log"

EOF