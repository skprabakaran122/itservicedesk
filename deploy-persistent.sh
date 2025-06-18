#!/bin/bash

echo "Deploy Persistent Fix - Ubuntu Server"
echo "===================================="

cat << 'EOF'
# Run this complete solution on Ubuntu server 98.81.235.7:

cd /var/www/itservicedesk

# Stop everything and check error logs
pm2 delete all 2>/dev/null || true
sudo fuser -k 5000/tcp 2>/dev/null || true

echo "Previous error analysis:"
cat /home/ubuntu/.pm2/logs/servicedesk-error-0.log 2>/dev/null | tail -15 || echo "No error logs"

# Verify database is accessible
echo ""
echo "Database test:"
sudo -u postgres psql -d servicedesk -c "SELECT count(*) FROM users;" 2>/dev/null || echo "Database issue detected"

# Rebuild with comprehensive externals
echo ""
echo "Rebuilding with fixed imports:"
npx esbuild server/index.ts \
  --platform=node \
  --packages=external \
  --bundle \
  --format=esm \
  --outdir=dist \
  --external:vite \
  --external:@vitejs/plugin-react \
  --external:drizzle-kit \
  --keep-names \
  --sourcemap

# Test direct execution
echo ""
echo "Testing direct execution:"
timeout 10s node dist/index.js 2>&1 | head -10 &
sleep 5
if ss -tlnp | grep -q :5000; then
    echo "✅ Direct execution works"
    curl -s http://localhost:5000/api/auth/me | head -3
else
    echo "❌ Direct execution failed"
fi
sudo pkill -f "node dist/index.js" 2>/dev/null

# Create production PM2 configuration
cat > production.config.cjs << 'PROD_EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'dist/index.js',
    instances: 1,
    autorestart: true,
    max_restarts: 3,
    min_uptime: '10s',
    restart_delay: 5000,
    env: {
      NODE_ENV: 'production',
      PORT: 5000,
      DATABASE_URL: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk',
      SESSION_SECRET: 'calpion-service-desk-secret-key-2025'
    }
  }]
};
PROD_EOF

# Start with monitoring
echo ""
echo "Starting application:"
pm2 start production.config.cjs
pm2 save

# Monitor for 60 seconds with detailed checking
for i in {1..20}; do
    echo "Check $i:"
    STATUS=$(pm2 list | grep servicedesk | awk '{print $10}')
    echo "  Status: $STATUS"
    
    if ss -tlnp | grep -q :5000; then
        echo "  ✅ Port 5000 bound!"
        
        # Test authentication
        AUTH=$(curl -s -X POST http://localhost:5000/api/auth/login \
          -H "Content-Type: application/json" \
          -d '{"username":"test.user","password":"password123"}')
        
        if echo "$AUTH" | grep -q "user"; then
            echo "  ✅ Authentication works!"
            echo "  ✅ HTTPS test:"
            curl -k -s https://98.81.235.7/api/auth/me | head -3
            echo ""
            echo "SUCCESS: IT Service Desk is running!"
            echo "- URL: https://98.81.235.7"
            echo "- Login: test.user / password123"
            break
        else
            echo "  Authentication failed: $AUTH"
        fi
    else
        echo "  Port not bound yet..."
        pm2 logs servicedesk --lines 2 --nostream 2>/dev/null
    fi
    
    if [ "$STATUS" = "errored" ]; then
        echo "  Process errored - checking logs:"
        pm2 logs servicedesk --lines 5 --nostream
        break
    fi
    
    sleep 3
done

echo ""
echo "Final status:"
pm2 status
ss -tlnp | grep :5000 && echo "Port 5000 bound" || echo "Port 5000 NOT bound"

EOF