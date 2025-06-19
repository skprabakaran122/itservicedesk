#!/bin/bash

# Use the exact same database configuration that works in development
set -e

cd /var/www/itservicedesk

echo "=== Using Working Database Configuration ==="

# Stop PM2
pm2 stop servicedesk 2>/dev/null || true

# Set the same DATABASE_URL that works in development
export DATABASE_URL="postgresql://neondb_owner:npg_CHFj1dqMYB6V@ep-still-snow-a65c90fl.us-west-2.aws.neon.tech/neondb?sslmode=require"

# Update the PM2 configuration to include the working DATABASE_URL
cat > ecosystem.production.config.cjs << 'EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'dist/index.js',
    cwd: '/var/www/itservicedesk',
    instances: 1,
    exec_mode: 'fork',
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production',
      PORT: 5000,
      DATABASE_URL: 'postgresql://neondb_owner:npg_CHFj1dqMYB6V@ep-still-snow-a65c90fl.us-west-2.aws.neon.tech/neondb?sslmode=require'
    },
    error_file: './logs/error.log',
    out_file: './logs/out.log',
    log_file: './logs/app.log',
    time: true
  }]
};
EOF

# Test with the working database
echo "Testing with working database..."
timeout 15s DATABASE_URL="$DATABASE_URL" node dist/index.js &
TEST_PID=$!
sleep 8

if curl -s http://localhost:5000/api/health >/dev/null 2>&1; then
    echo "✓ Application working with Neon database"
    kill $TEST_PID 2>/dev/null || true
else
    echo "✗ Still having issues"
    kill $TEST_PID 2>/dev/null || true
    timeout 5s DATABASE_URL="$DATABASE_URL" node dist/index.js 2>&1 | head -15
    exit 1
fi

# Start with PM2 using the working configuration
echo "Starting PM2 with working database..."
pm2 start ecosystem.production.config.cjs

sleep 10

# Check status
pm2 status

# Test the working application
echo "Testing working application..."
curl -s http://localhost:5000/api/health

echo ""
echo "=== Production Using Same Database as Development ==="
echo "✓ Using Neon Database (same as development)"
echo "✓ No local PostgreSQL configuration needed"
echo "✓ Same authentication that works in development"
echo ""
echo "Your IT Service Desk is now at: http://98.81.235.7"
echo "Same database, users, and data as development environment"