#!/bin/bash

echo "Final PM2 Fix - Production Ready Build"
echo "====================================="

cat << 'EOF'
# Complete fix for Ubuntu server 98.81.235.7:

cd /var/www/itservicedesk

# Clean shutdown
pm2 delete all 2>/dev/null || true
sudo pkill -f node 2>/dev/null || true
sudo fuser -k 5000/tcp 2>/dev/null || true

# Install missing dependencies
npm install vite esbuild

# Build application properly for production
echo "Building frontend..."
npx vite build

echo "Building backend with proper external handling..."
npx esbuild server/index.ts \
  --platform=node \
  --packages=external \
  --bundle \
  --format=esm \
  --outdir=dist \
  --external:vite \
  --external:@vitejs/plugin-react

# Create production-ready PM2 config
cat > production.config.cjs << 'PROD_EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'dist/index.js',
    cwd: '/var/www/itservicedesk',
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
    error_file: '/var/log/pm2/servicedesk-error.log',
    out_file: '/var/log/pm2/servicedesk-out.log'
  }]
};
PROD_EOF

# Ensure log directory exists
sudo mkdir -p /var/log/pm2
sudo chown ubuntu:ubuntu /var/log/pm2

# Start application
pm2 start production.config.cjs
pm2 save

# Monitor startup
echo "Monitoring startup..."
for i in {1..20}; do
    if netstat -tlnp 2>/dev/null | grep -q ":5000 " || ss -tlnp 2>/dev/null | grep -q ":5000 "; then
        echo "✅ Application started on port 5000"
        break
    fi
    echo "Waiting... ($i/20)"
    sleep 3
done

# Test authentication
echo "Testing authentication..."
sleep 5
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.user","password":"password123"}' \
  -w "\nStatus: %{http_code}\n"

echo "Testing external access..."
curl -k https://98.81.235.7/api/auth/me -w "\nStatus: %{http_code}\n"

echo "PM2 Status:"
pm2 status

echo "Application logs:"
pm2 logs servicedesk --lines 5

EOF