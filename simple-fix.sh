#!/bin/bash

echo "Simple Fix for IT Service Desk"
echo "=============================="

# Get current directory (should be where the project is)
PROJECT_DIR=$(pwd)
echo "Working in: $PROJECT_DIR"

# Stop any existing PM2 processes
pm2 delete all 2>/dev/null || true

# Create simple PM2 config that works
cat > simple.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'server/index.ts',
    interpreter: 'node',
    interpreter_args: '--loader tsx',
    cwd: process.cwd(),
    instances: 1,
    autorestart: true,
    watch: false,
    env: {
      NODE_ENV: 'production',
      PORT: 3000,
      DATABASE_URL: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk'
    }
  }]
};
EOF

# Install tsx globally if not present
npm install -g tsx 2>/dev/null || true

# Start the application
pm2 start simple.config.js

sleep 5

# Check if running
if curl -f http://localhost:3000 > /dev/null 2>&1; then
    echo "✓ Application running on port 3000"
    echo "Your IT Service Desk is available at: https://98.81.235.7"
else
    echo "Checking status..."
    pm2 status
    echo ""
    pm2 logs servicedesk --lines 10
fi