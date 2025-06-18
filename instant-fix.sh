#!/bin/bash

# Instant fix for the PM2 deployment failure
# Addresses MODULE_NOT_FOUND and DATABASE_URL errors

cd /var/www/itservicedesk

# Kill all PM2 processes and clean state
pm2 kill
sleep 2

# Ensure production file exists
mkdir -p dist logs
cp server/production.cjs dist/production.cjs

# Create environment file
cat > .env << 'EOF'
DATABASE_URL=postgresql://ubuntu:password@localhost:5432/servicedesk
NODE_ENV=production
PORT=5000
EOF

# Update PM2 config with explicit paths and environment
cat > ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'itservicedesk',
    script: '/var/www/itservicedesk/dist/production.cjs',
    cwd: '/var/www/itservicedesk',
    instances: 1,
    exec_mode: 'fork',
    env: {
      NODE_ENV: 'production',
      PORT: 5000,
      DATABASE_URL: 'postgresql://ubuntu:password@localhost:5432/servicedesk'
    },
    env_file: '/var/www/itservicedesk/.env',
    error_file: '/var/www/itservicedesk/logs/err.log',
    out_file: '/var/www/itservicedesk/logs/out.log',
    log_file: '/var/www/itservicedesk/logs/combined.log',
    time: true,
    max_memory_restart: '1G',
    restart_delay: 2000,
    watch: false
  }]
};
EOF

# Start PM2 with explicit environment
export DATABASE_URL="postgresql://ubuntu:password@localhost:5432/servicedesk"
export NODE_ENV="production"
export PORT="5000"

pm2 start ecosystem.config.js
pm2 save

echo "Waiting for application to start..."
sleep 10

# Test the application
if curl -s http://localhost:5000/health | grep -q "OK"; then
    echo "SUCCESS: Application is now running"
    pm2 status
else
    echo "FAILED: Application still not responding"
    echo "Checking logs..."
    pm2 logs itservicedesk --lines 10
fi