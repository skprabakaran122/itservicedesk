#!/bin/bash

echo "Restart Ubuntu Server - Diagnostic and Fix"
echo "========================================="

cat << 'EOF'
# Run on Ubuntu server to diagnose and fix port binding issue:

cd /var/www/itservicedesk

# Clean stop everything
pm2 delete all 2>/dev/null || true
sudo fuser -k 5000/tcp 2>/dev/null || true
sleep 3

# Check what was in the logs before restart
echo "Previous PM2 logs:"
ls -la /home/ubuntu/.pm2/logs/ 2>/dev/null || echo "No PM2 logs directory"
cat /home/ubuntu/.pm2/logs/servicedesk-error-0.log 2>/dev/null | tail -10 || echo "No error logs"
cat /home/ubuntu/.pm2/logs/servicedesk-out-0.log 2>/dev/null | tail -10 || echo "No output logs"

# Test the built file directly
echo ""
echo "Testing built file directly:"
NODE_ENV=production PORT=5000 timeout 10s node dist/index.js &
sleep 5
ss -tlnp | grep :5000 && echo "✅ Direct node works!" || echo "❌ Direct node failed"
sudo pkill -f "node dist/index.js" 2>/dev/null || true

# Check if the issue is in the built code
echo ""
echo "Checking built file structure:"
head -20 dist/index.js

# Rebuild with better error handling
echo ""
echo "Rebuilding with production optimizations:"
npx esbuild server/index.ts \
  --platform=node \
  --packages=external \
  --bundle \
  --format=esm \
  --outdir=dist \
  --external:vite \
  --external:@vitejs/plugin-react \
  --minify=false \
  --keep-names \
  --sourcemap

# Create super simple PM2 config with verbose logging
cat > simple.config.cjs << 'SIMPLE_EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'dist/index.js',
    instances: 1,
    autorestart: true,
    watch: false,
    max_restarts: 10,
    min_uptime: '10s',
    restart_delay: 5000,
    env: {
      NODE_ENV: 'production',
      PORT: 5000,
      DATABASE_URL: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk',
      SESSION_SECRET: 'calpion-service-desk-secret-key-2025'
    },
    combine_logs: true,
    merge_logs: true
  }]
};
SIMPLE_EOF

# Start with detailed monitoring
echo ""
echo "Starting application with monitoring:"
pm2 start simple.config.cjs

# Monitor the startup process in detail
for i in {1..30}; do
    echo "--- Check $i ---"
    
    # Check PM2 process
    PM2_STATUS=$(pm2 list | grep servicedesk | awk '{print $10}' || echo "not_found")
    echo "PM2 Status: $PM2_STATUS"
    
    # Check actual node process
    NODE_PROC=$(ps aux | grep "node.*dist/index.js" | grep -v grep | awk '{print $2}' || echo "none")
    echo "Node PID: $NODE_PROC"
    
    # Check port
    PORT_STATUS=$(ss -tlnp | grep :5000 || echo "not_bound")
    echo "Port 5000: $PORT_STATUS"
    
    # Check recent logs
    pm2 logs servicedesk --lines 3 --nostream 2>/dev/null || echo "No logs available"
    
    if [[ "$PORT_STATUS" != "not_bound" ]]; then
        echo "✅ SUCCESS! Port 5000 is bound"
        break
    fi
    
    if [[ "$PM2_STATUS" == "errored" ]]; then
        echo "❌ PM2 process errored - checking logs"
        pm2 logs servicedesk --lines 10 --nostream
        break
    fi
    
    sleep 2
done

# Final comprehensive test
echo ""
echo "=== FINAL VERIFICATION ==="
pm2 status
echo ""
ss -tlnp | grep :5000 && echo "Port 5000 bound" || echo "Port 5000 NOT bound"
echo ""

# Test if application responds
if ss -tlnp | grep -q :5000; then
    echo "Testing application response:"
    curl -m 5 -s http://localhost:5000/api/auth/me || echo "No response"
    
    echo ""
    echo "Testing authentication:"
    curl -m 5 -X POST http://localhost:5000/api/auth/login \
      -H "Content-Type: application/json" \
      -d '{"username":"test.user","password":"password123"}' \
      -s || echo "Auth failed"
      
    echo ""
    echo "Testing external access:"
    curl -m 5 -k https://98.81.235.7/api/auth/me -s || echo "External access failed"
else
    echo "Cannot test application - port not bound"
    echo "Final PM2 logs:"
    pm2 logs servicedesk --lines 15
fi

EOF