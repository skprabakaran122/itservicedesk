#!/bin/bash

# Immediate fix for non-responding application
echo "Diagnosing and fixing application startup..."

cd /var/www/servicedesk

# Check if environment variables are accessible
echo "1. Testing environment variables..."
cat .env
echo ""

# Test if tsx can load the application with env vars
echo "2. Testing direct startup with environment loading..."
export $(cat .env | xargs)
timeout 10s tsx server/index.ts &
TEST_PID=$!
sleep 3

if kill -0 $TEST_PID 2>/dev/null; then
    echo "✓ Application starts with explicit environment loading"
    kill $TEST_PID 2>/dev/null
else
    echo "Application still failing - checking server/db.ts"
fi

# Check if server/db.ts has dotenv import
echo "3. Checking server/db.ts configuration..."
if grep -q "import.*dotenv" server/db.ts; then
    echo "dotenv import found in server/db.ts"
else
    echo "Adding dotenv import to server/db.ts..."
    cp server/db.ts server/db.ts.backup.$(date +%s)
    
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

# Update PM2 config to explicitly load environment
echo "4. Updating PM2 configuration..."
cat > ecosystem.config.cjs << 'EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'tsx',
    args: 'server/index.ts',
    cwd: '/var/www/servicedesk',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env_file: '/var/www/servicedesk/.env',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    error_file: '/var/log/servicedesk/error.log',
    out_file: '/var/log/servicedesk/out.log',
    log_file: '/var/log/servicedesk/combined.log',
    time: true
  }]
};
EOF

# Restart PM2 with new configuration
echo "5. Restarting application..."
pm2 delete servicedesk 2>/dev/null || true
pm2 start ecosystem.config.cjs
pm2 save

# Wait and test
sleep 8

echo "6. Final test..."
if curl -s http://localhost:3000 > /dev/null; then
    echo "✅ SUCCESS! Application is now responding"
    echo "Your IT Service Desk is accessible at: http://98.81.235.7"
    
    # Show sample response
    echo "Sample response:"
    curl -s http://localhost:3000 | head -3
else
    echo "Still not responding. Checking detailed logs..."
    pm2 logs servicedesk --lines 15
    
    echo ""
    echo "Manual test with explicit environment:"
    cd /var/www/servicedesk
    export DATABASE_URL="postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk"
    export NODE_ENV="production"
    export PORT="3000"
    timeout 5s tsx server/index.ts
fi

echo ""
pm2 status