#!/bin/bash

# Fix DATABASE_URL environment variable issue
echo "Fixing DATABASE_URL environment variable issue..."

cd /var/www/servicedesk

# Stop PM2 process
pm2 delete servicedesk 2>/dev/null || true

# Update the PM2 ecosystem configuration to properly load environment variables
echo "Updating PM2 configuration to load .env file..."
cat > ecosystem.config.cjs << 'EOF'
const path = require('path');

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
    env_file: '/var/www/servicedesk/.env',
    error_file: '/var/log/servicedesk/error.log',
    out_file: '/var/log/servicedesk/out.log',
    log_file: '/var/log/servicedesk/combined.log',
    time: true
  }]
};
EOF

# Alternative: Add dotenv loading directly to the application
echo "Adding dotenv configuration to ensure environment variables are loaded..."

# Check if dotenv is already in the server/index.ts
if ! grep -q "dotenv" server/index.ts; then
    # Create a temporary file with dotenv import at the top
    cat > temp_index.ts << 'EOF'
import 'dotenv/config';
EOF
    cat server/index.ts >> temp_index.ts
    mv temp_index.ts server/index.ts
    echo "Added dotenv/config import to server/index.ts"
fi

# Install dotenv if not present
if ! npm list dotenv > /dev/null 2>&1; then
    echo "Installing dotenv package..."
    npm install dotenv
fi

# Test environment loading
echo "Testing environment variable loading..."
cat > test_env.js << 'EOF'
require('dotenv').config();
console.log('DATABASE_URL:', process.env.DATABASE_URL ? 'Found' : 'Not found');
console.log('NODE_ENV:', process.env.NODE_ENV);
console.log('PORT:', process.env.PORT);
EOF

node test_env.js
rm test_env.js

# Start PM2 with the updated configuration
echo "Starting PM2 with environment variable support..."
pm2 start ecosystem.config.cjs
pm2 save

# Wait and test
sleep 5

echo "Testing application response..."
if curl -s http://localhost:3000 > /dev/null; then
    echo "✓ Application is now responding on port 3000!"
    echo "Your IT Service Desk is accessible at: http://98.81.235.7"
else
    echo "Checking PM2 logs for any remaining issues..."
    pm2 logs servicedesk --lines 10
fi

echo "PM2 Status:"
pm2 status