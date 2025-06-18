#!/bin/bash

# Fix module loading order for environment variables
echo "Fixing module loading order for environment variables..."

cd /var/www/servicedesk

# Stop PM2 process
pm2 delete servicedesk 2>/dev/null || true

# Method 1: Fix server/db.ts to handle missing env gracefully
echo "Updating server/db.ts to handle environment loading order..."
cp server/db.ts server/db.ts.backup

# Check if the current db.ts has the issue
if grep -q "throw new Error.*DATABASE_URL must be set" server/db.ts; then
    echo "Fixing DATABASE_URL check in server/db.ts..."
    
    # Create a new db.ts that loads dotenv first
    cat > server/db.ts << 'EOF'
import { config } from 'dotenv';
config();

import { Pool, neonConfig } from '@neondatabase/serverless';
import { drizzle } from 'drizzle-orm/neon-serverless';
import ws from "ws";
import * as schema from "@shared/schema";

neonConfig.webSocketConstructor = ws;

if (!process.env.DATABASE_URL) {
  throw new Error(
    "DATABASE_URL must be set. Did you forget to provision a database?",
  );
}

export const pool = new Pool({ connectionString: process.env.DATABASE_URL });
export const db = drizzle({ client: pool, schema });
EOF
    
    echo "Updated server/db.ts with dotenv loading"
fi

# Method 2: Use NODE_OPTIONS to preload dotenv
echo "Setting up NODE_OPTIONS for dotenv preloading..."

# Update PM2 configuration to preload dotenv
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
      PORT: 3000,
      NODE_OPTIONS: '--loader ./dotenv-loader.mjs'
    },
    error_file: '/var/log/servicedesk/error.log',
    out_file: '/var/log/servicedesk/out.log',
    log_file: '/var/log/servicedesk/combined.log',
    time: true
  }]
};
EOF

# Create a dotenv loader module
cat > dotenv-loader.mjs << 'EOF'
import { config } from 'dotenv';
config();
EOF

# Test the fixed version
echo "Testing fixed database connection..."
timeout 10s tsx server/index.ts &
TEST_PID=$!
sleep 5

if kill -0 $TEST_PID 2>/dev/null; then
    echo "✓ Application started successfully!"
    kill $TEST_PID 2>/dev/null || true
    
    # Start with PM2
    echo "Starting with PM2..."
    pm2 start ecosystem.config.cjs
    pm2 save
    
    # Final test
    sleep 8
    if curl -s http://localhost:3000 > /dev/null; then
        echo "✅ SUCCESS! Your IT Service Desk is now running!"
        echo "Accessible at: http://98.81.235.7"
        
        # Show sample response
        echo "Sample response:"
        curl -s http://localhost:3000 | head -3
    else
        echo "Application started but not responding on port 3000"
        pm2 logs servicedesk --lines 5
    fi
else
    echo "Application still failing to start"
    echo "Trying alternative method with explicit environment loading..."
    
    # Method 3: Start with explicit environment
    DATABASE_URL="$(grep DATABASE_URL .env | cut -d= -f2-)" \
    NODE_ENV="production" \
    PORT="3000" \
    pm2 start ecosystem.config.cjs
    pm2 save
    
    sleep 5
    if curl -s http://localhost:3000 > /dev/null; then
        echo "✅ SUCCESS with explicit environment variables!"
        echo "Your IT Service Desk is accessible at: http://98.81.235.7"
    else
        echo "Still failing. Checking detailed logs..."
        pm2 logs servicedesk --lines 10
    fi
fi

echo ""
echo "Final PM2 status:"
pm2 status