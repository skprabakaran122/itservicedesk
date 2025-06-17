#!/bin/bash

# Fix ES modules environment variable loading
echo "Fixing ES modules environment variable loading..."

cd /var/www/servicedesk

# Stop PM2 process
pm2 delete servicedesk 2>/dev/null || true

# Check current server/index.ts
echo "Checking current server/index.ts..."
if grep -q "import.*dotenv" server/index.ts; then
    echo "dotenv import already exists"
else
    echo "Adding proper dotenv import for ES modules..."
    # Create backup
    cp server/index.ts server/index.ts.backup
    
    # Add dotenv import at the very top
    cat > temp_index.ts << 'EOF'
import { config } from 'dotenv';
config();

EOF
    cat server/index.ts >> temp_index.ts
    mv temp_index.ts server/index.ts
    echo "Added dotenv config to server/index.ts"
fi

# Test environment loading with ES modules
echo "Testing environment variable loading with ES modules..."
cat > test_env.mjs << 'EOF'
import { config } from 'dotenv';
config();
console.log('DATABASE_URL:', process.env.DATABASE_URL ? 'Found' : 'Not found');
console.log('NODE_ENV:', process.env.NODE_ENV);
console.log('PORT:', process.env.PORT);
if (process.env.DATABASE_URL) {
    console.log('Database URL starts with:', process.env.DATABASE_URL.substring(0, 20) + '...');
}
EOF

node test_env.mjs
rm test_env.mjs

# Update PM2 configuration for ES modules
echo "Updating PM2 configuration for ES modules..."
cat > ecosystem.config.cjs << 'EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: '/usr/bin/tsx',
    args: 'server/index.ts',
    cwd: '/var/www/servicedesk',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    error_file: '/var/log/servicedesk/error.log',
    out_file: '/var/log/servicedesk/out.log',
    log_file: '/var/log/servicedesk/combined.log',
    time: true,
    node_args: []
  }]
};
EOF

# Test direct startup with proper dotenv
echo "Testing direct startup..."
timeout 10s tsx server/index.ts &
STARTUP_PID=$!
sleep 5

if kill -0 $STARTUP_PID 2>/dev/null; then
    echo "✓ Application started successfully with environment variables"
    kill $STARTUP_PID 2>/dev/null || true
else
    echo "Application still failing, checking logs..."
fi

# Start with PM2
echo "Starting with PM2..."
pm2 start ecosystem.config.cjs
pm2 save

# Wait and test
sleep 8

echo "Final test..."
if curl -s http://localhost:3000 > /dev/null; then
    echo "✓ SUCCESS! Application is responding on port 3000"
    echo "Your IT Service Desk is now accessible at: http://98.81.235.7"
    
    # Test the actual response
    echo "Testing response content..."
    curl -s http://localhost:3000 | head -5
else
    echo "Still not responding, checking detailed PM2 logs..."
    pm2 logs servicedesk --lines 15
    
    echo ""
    echo "Checking process details..."
    pm2 show servicedesk
fi

echo ""
echo "Current PM2 status:"
pm2 status