#!/bin/bash

echo "Complete Ubuntu Deployment Diagnostic and Fix"
echo "============================================="

cat << 'EOF'
# Run on Ubuntu server 98.81.235.7:

cd /var/www/itservicedesk

# Stop everything and check logs first
pm2 delete all 2>/dev/null || true
sudo fuser -k 5000/tcp 2>/dev/null || true

echo "=== CHECKING PREVIOUS LOGS ==="
pm2 logs --lines 15 2>/dev/null || echo "No previous logs"

echo ""
echo "=== CHECKING BUILD OUTPUT ==="
ls -la dist/
file dist/index.js

echo ""
echo "=== TESTING NODE DIRECTLY ==="
# Test if the built file can run at all
timeout 15s node dist/index.js 2>&1 | head -10 &
sleep 5
ps aux | grep "node dist/index.js" | grep -v grep || echo "Node process not running"

# Kill any test processes
sudo pkill -f "node dist/index.js" 2>/dev/null || true

echo ""
echo "=== REBUILDING WITH VERBOSE OUTPUT ==="
npx esbuild server/index.ts \
  --platform=node \
  --packages=external \
  --bundle \
  --format=esm \
  --outdir=dist \
  --external:vite \
  --external:@vitejs/plugin-react \
  --log-level=info

echo ""
echo "=== CREATING MINIMAL PM2 CONFIG ==="
cat > minimal.config.cjs << 'MINIMAL_EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'dist/index.js',
    instances: 1,
    autorestart: true,
    env: {
      NODE_ENV: 'production',
      PORT: 5000,
      DATABASE_URL: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk'
    },
    error_file: './pm2-error.log',
    out_file: './pm2-out.log',
    log_file: './pm2.log'
  }]
};
MINIMAL_EOF

echo ""
echo "=== STARTING WITH MINIMAL CONFIG ==="
pm2 start minimal.config.cjs

echo ""
echo "=== MONITORING STARTUP ==="
for i in {1..20}; do
    echo "Check $i: $(date)"
    
    # Check PM2 status
    pm2 list | grep servicedesk || echo "PM2 process not found"
    
    # Check logs for errors
    if [ -f pm2-error.log ]; then
        echo "Error log:"
        tail -5 pm2-error.log 2>/dev/null || echo "No errors in log"
    fi
    
    if [ -f pm2-out.log ]; then
        echo "Output log:"
        tail -5 pm2-out.log 2>/dev/null || echo "No output in log"
    fi
    
    # Check port binding
    if ss -tlnp | grep -q ":5000"; then
        echo "✅ SUCCESS: Port 5000 is bound!"
        break
    else
        echo "Port 5000 not bound yet..."
    fi
    
    sleep 3
done

echo ""
echo "=== FINAL STATUS ==="
pm2 status
echo ""
echo "Port status:"
ss -tlnp | grep :5000 || echo "Port 5000 not bound"
echo ""
echo "Process check:"
ps aux | grep servicedesk | grep -v grep || echo "No servicedesk process"

echo ""
echo "=== TESTING APPLICATION ==="
if ss -tlnp | grep -q ":5000"; then
    echo "Testing API response..."
    curl -s http://localhost:5000/api/auth/me | head -5
    
    echo ""
    echo "Testing authentication..."
    curl -X POST http://localhost:5000/api/auth/login \
      -H "Content-Type: application/json" \
      -d '{"username":"test.user","password":"password123"}' \
      -s | head -10
      
    echo ""
    echo "Testing external HTTPS..."
    curl -k -s https://98.81.235.7/api/auth/me | head -5
else
    echo "Cannot test - port 5000 not available"
    echo "Check logs:"
    cat pm2-error.log 2>/dev/null || echo "No error log"
    cat pm2-out.log 2>/dev/null || echo "No output log"
fi

EOF