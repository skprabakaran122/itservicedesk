#!/bin/bash

# Direct PM2 fix - create the .cjs config and start properly
cd /var/www/itservicedesk

# Stop all PM2 processes
pm2 stop all 2>/dev/null || true
pm2 delete all 2>/dev/null || true
pm2 kill

# Set environment variables
export DATABASE_URL="postgresql://ubuntu:password@localhost:5432/servicedesk"
export NODE_ENV="production"
export PORT="5000"

# Ensure production file exists
mkdir -p dist logs
cp server/production.cjs dist/production.cjs

# Create the PM2 config file
cat > ecosystem.config.cjs << 'EOF'
module.exports = {
  apps: [{
    name: 'itservicedesk',
    script: 'dist/production.cjs',
    instances: 1,
    exec_mode: 'fork',
    cwd: '/var/www/itservicedesk',
    env: {
      NODE_ENV: 'production',
      PORT: 5000,
      DATABASE_URL: 'postgresql://ubuntu:password@localhost:5432/servicedesk'
    },
    error_file: './logs/err.log',
    out_file: './logs/out.log',
    log_file: './logs/combined.log',
    time: true,
    max_memory_restart: '1G',
    restart_delay: 4000,
    watch: false,
    ignore_watch: ['node_modules', 'logs', 'dist'],
    kill_timeout: 5000
  }]
};
EOF

# Start using the .cjs config
pm2 start ecosystem.config.cjs
pm2 save

# Wait and test
sleep 10

# Check status
echo "PM2 Status:"
pm2 status

# Test application
echo "Testing application:"
if curl -s http://localhost:5000/health | grep -q "OK"; then
    echo "SUCCESS: Application is running"
    
    # Test HTTPS through nginx
    if curl -k -s https://localhost/health | grep -q "OK"; then
        echo "SUCCESS: HTTPS proxy working"
        SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "your-server-ip")
        echo "Access: https://$SERVER_IP"
        echo "Login: john.doe / password123"
    else
        echo "Application running but HTTPS needs checking"
    fi
else
    echo "FAILED: Application not responding"
    echo "Error logs:"
    pm2 logs itservicedesk --err --lines 10
fi