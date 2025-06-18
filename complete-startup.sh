#!/bin/bash

echo "Complete Ubuntu Server Startup Fix"
echo "================================="

cat << 'EOF'
# Run on Ubuntu server 98.81.235.7:

cd /var/www/itservicedesk

# Clean shutdown
pm2 delete all 2>/dev/null || true
sudo pkill -f "node.*servicedesk" 2>/dev/null || true
sudo fuser -k 5000/tcp 2>/dev/null || true

# Check database connection first
echo "Testing database connection..."
sudo -u postgres psql -d servicedesk -c "SELECT 1;" 2>/dev/null || {
    echo "Database issue detected. Restarting PostgreSQL..."
    sudo systemctl restart postgresql
    sleep 5
}

# Ensure proper .env configuration
cat > .env << 'ENV_EOF'
DATABASE_URL=postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk
NODE_ENV=production
PORT=5000
SESSION_SECRET=calpion-service-desk-secret-key-2025
ENV_EOF

# Build if dist doesn't exist or is outdated
if [ ! -f "dist/index.js" ] || [ "server/index.ts" -nt "dist/index.js" ]; then
    echo "Building application..."
    npm run build 2>/dev/null || {
        # Fallback build
        npx vite build 2>/dev/null || echo "Frontend build skipped"
        npx esbuild server/index.ts --platform=node --packages=external --bundle --format=esm --outdir=dist 2>/dev/null || echo "Backend build failed"
    }
fi

# Create optimized PM2 config
cat > startup.config.cjs << 'CONFIG_EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'dist/index.js',
    cwd: '/var/www/itservicedesk',
    instances: 1,
    autorestart: true,
    max_restarts: 3,
    restart_delay: 5000,
    env: {
      NODE_ENV: 'production',
      PORT: 5000,
      DATABASE_URL: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk',
      SESSION_SECRET: 'calpion-service-desk-secret-key-2025'
    },
    error_file: '/var/log/pm2/servicedesk-error.log',
    out_file: '/var/log/pm2/servicedesk-out.log',
    log_file: '/var/log/pm2/servicedesk.log'
  }]
};
CONFIG_EOF

# Create log directory
sudo mkdir -p /var/log/pm2
sudo chown ubuntu:ubuntu /var/log/pm2

# Start application with proper monitoring
pm2 start startup.config.cjs
pm2 save

# Monitor startup process
echo "Monitoring startup..."
for i in {1..30}; do
    if netstat -tlnp 2>/dev/null | grep -q ":5000 " || ss -tlnp 2>/dev/null | grep -q ":5000 "; then
        echo "Application started successfully on port 5000"
        break
    fi
    echo "Waiting for startup... ($i/30)"
    sleep 2
done

# Comprehensive testing
echo "=== TESTING ==="
echo "Port status:"
netstat -tlnp | grep :5000 || ss -tlnp | grep :5000

echo "PM2 status:"
pm2 status

echo "Application health check:"
curl -s http://localhost:5000/api/auth/me | head -10

echo "External access test:"
curl -k -s https://98.81.235.7/api/auth/me | head -10

echo "Authentication test:"
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.user","password":"password123"}' \
  -s | head -10

echo "Logs (if any errors):"
pm2 logs servicedesk --lines 5

EOF