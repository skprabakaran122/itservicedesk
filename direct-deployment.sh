#!/bin/bash

echo "Direct TypeScript Deployment for Ubuntu Server"
echo "=============================================="

cat << 'EOF'
# Alternative deployment that avoids build issues entirely
# Run on Ubuntu server:

# Clean stop
pm2 delete all 2>/dev/null || true
sudo pkill -f "node.*servicedesk" 2>/dev/null || true

cd /var/www/itservicedesk

# Install TypeScript runtime
npm install -g tsx@latest

# Ensure all dependencies are installed
npm install --production=false

# Create direct execution PM2 config
cat > direct.config.js << 'DIRECT_EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'node_modules/.bin/tsx',
    args: 'server/index.ts',
    cwd: '/var/www/itservicedesk',
    instances: 1,
    autorestart: true,
    max_restarts: 5,
    env: {
      NODE_ENV: 'production',
      PORT: 3000,
      DATABASE_URL: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk'
    },
    log_file: '/var/www/itservicedesk/logs/combined.log',
    out_file: '/var/www/itservicedesk/logs/out.log',
    error_file: '/var/www/itservicedesk/logs/error.log'
  }]
};
DIRECT_EOF

# Create logs directory
mkdir -p logs

# Test TypeScript execution locally first
echo "Testing TypeScript execution..."
timeout 10s node_modules/.bin/tsx server/index.ts &
TSX_PID=$!
sleep 5

if kill -0 $TSX_PID 2>/dev/null; then
  echo "TypeScript execution successful"
  kill $TSX_PID
else
  echo "TypeScript execution failed - checking dependencies"
  npm list tsx
fi

# Start with PM2
pm2 start direct.config.js
pm2 save

# Monitor startup
sleep 15

echo "Application status:"
pm2 status

echo "Recent logs:"
pm2 logs servicedesk --lines 10

# Test authentication
echo "Testing authentication endpoint..."
AUTH_RESPONSE=$(curl -s -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.user","password":"password123"}')

echo "Auth response: $AUTH_RESPONSE"

# Test external access
echo "Testing external access..."
curl -k -s -w "Status: %{http_code}\n" https://98.81.235.7/api/auth/me

EOF

echo ""
echo "This deployment method:"
echo "- Runs TypeScript directly without building"
echo "- Avoids module resolution issues"
echo "- Uses the authentication fixes"
echo "- Should start immediately"