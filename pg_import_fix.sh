#!/bin/bash

echo "Fixing PostgreSQL import for ES modules..."

cd /var/www/servicedesk

# Fix the import syntax in server/db.ts
echo "1. Updating server/db.ts with correct ES modules import..."
cp server/db.ts server/db.ts.backup.$(date +%s)

cat > server/db.ts << 'EOF'
import { config } from 'dotenv';
config();

import pkg from 'pg';
const { Pool } = pkg;
import { drizzle } from 'drizzle-orm/node-postgres';
import * as schema from "@shared/schema";

if (!process.env.DATABASE_URL) {
  throw new Error(
    "DATABASE_URL must be set. Did you forget to provision a database?",
  );
}

console.log('[Database] Connecting to local PostgreSQL...');
export const pool = new Pool({ 
  connectionString: process.env.DATABASE_URL,
  ssl: false
});

export const db = drizzle(pool, { schema });

// Test connection on startup
pool.connect((err, client, release) => {
  if (err) {
    console.error('[Database] Connection error:', err);
  } else {
    console.log('[Database] Connected successfully to local PostgreSQL');
    release();
  }
});
EOF

echo "Updated server/db.ts with default import syntax"

# Test the fix
echo ""
echo "2. Testing application startup with fixed imports..."
export DATABASE_URL="postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk"
export NODE_ENV="production"
export PORT="3000"

timeout 15s tsx server/index.ts &
APP_PID=$!
sleep 8

if kill -0 $APP_PID 2>/dev/null; then
    echo "✓ Application started successfully"
    
    # Test HTTP response
    sleep 3
    if curl -s http://localhost:3000 > /dev/null; then
        echo "✅ SUCCESS! Application responds to HTTP requests"
        kill $APP_PID 2>/dev/null
        
        echo ""
        echo "3. Starting with PM2..."
        
        # Update PM2 config
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
    env: {
      NODE_ENV: 'production',
      PORT: 3000,
      DATABASE_URL: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk'
    },
    error_file: '/var/log/servicedesk/error.log',
    out_file: '/var/log/servicedesk/out.log',
    log_file: '/var/log/servicedesk/combined.log',
    time: true
  }]
};
EOF

        pm2 delete servicedesk 2>/dev/null || true
        pm2 start ecosystem.config.cjs
        pm2 save
        
        sleep 12
        
        if curl -s http://localhost:3000 > /dev/null; then
            echo "✅ COMPLETE SUCCESS!"
            echo "Your IT Service Desk is now accessible at: http://98.81.235.7"
            echo ""
            echo "Sample response:"
            curl -s http://localhost:3000 | head -3
            echo ""
            pm2 status
        else
            echo "PM2 startup issue. Checking logs..."
            pm2 logs servicedesk --lines 15
        fi
    else
        echo "❌ Application still not responding to HTTP"
        kill $APP_PID 2>/dev/null
        echo "Checking application output..."
        tsx server/index.ts 2>&1 | head -25
    fi
else
    echo "❌ Application still fails to start"
    echo "Checking startup errors..."
    tsx server/index.ts 2>&1 | head -25
fi

echo ""
echo "=== FINAL STATUS ==="
echo "Local PostgreSQL: $(psql -h localhost -U servicedesk -d servicedesk -c 'SELECT 1;' 2>/dev/null && echo 'Connected' || echo 'Failed')"
echo "Application: $(curl -s http://localhost:3000 > /dev/null && echo 'Running' || echo 'Not responding')"
echo "Nginx: $(nginx -t 2>/dev/null && echo 'OK' || echo 'Error')"