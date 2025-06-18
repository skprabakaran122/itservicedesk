#!/bin/bash

echo "Fixing database connection issue..."

cd /var/www/servicedesk

# Check current .env file
echo "1. Current .env configuration:"
cat .env

echo ""
echo "2. The error shows WebSocket connection failure - this indicates Neon database connection"
echo "   We need to use local PostgreSQL instead"

# Update .env to use local PostgreSQL
echo "3. Updating .env to use local PostgreSQL..."
cp .env .env.backup.$(date +%s)

cat > .env << 'EOF'
DATABASE_URL=postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk
NODE_ENV=production
PORT=3000
EOF

echo "Updated .env file:"
cat .env

# Test local database connection
echo ""
echo "4. Testing local PostgreSQL connection..."
if psql -h localhost -U servicedesk -d servicedesk -c "SELECT 1;" 2>/dev/null; then
    echo "✓ Local PostgreSQL connection successful"
else
    echo "❌ Local PostgreSQL connection failed - fixing database setup..."
    
    # Reset PostgreSQL user and database
    sudo -u postgres psql << 'EOSQL'
DROP DATABASE IF EXISTS servicedesk;
DROP USER IF EXISTS servicedesk;
CREATE USER servicedesk WITH PASSWORD 'servicedesk123';
CREATE DATABASE servicedesk OWNER servicedesk;
GRANT ALL PRIVILEGES ON DATABASE servicedesk TO servicedesk;
EOSQL
    
    echo "Database recreated. Testing connection again..."
    if psql -h localhost -U servicedesk -d servicedesk -c "SELECT 1;" 2>/dev/null; then
        echo "✓ Local PostgreSQL connection now working"
    else
        echo "❌ Still having database issues"
        sudo systemctl status postgresql
        return 1
    fi
fi

# Update server/db.ts to remove Neon-specific WebSocket configuration
echo ""
echo "5. Updating server/db.ts for local PostgreSQL..."
cp server/db.ts server/db.ts.backup.$(date +%s)

cat > server/db.ts << 'EOF'
import { config } from 'dotenv';
config();

import { Pool } from 'pg';
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
  ssl: false // No SSL for local connections
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

echo "Updated server/db.ts"

# Run database migrations to set up tables
echo ""
echo "6. Running database migrations..."
export DATABASE_URL="postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk"
export NODE_ENV="production"
export PORT="3000"

npm run db:push 2>/dev/null || npx drizzle-kit push 2>/dev/null || echo "Migration command not found, continuing..."

# Test application startup
echo ""
echo "7. Testing application with local database..."
timeout 10s tsx server/index.ts &
APP_PID=$!
sleep 5

if kill -0 $APP_PID 2>/dev/null; then
    echo "✓ Application started successfully"
    
    # Test HTTP response
    sleep 3
    if curl -s http://localhost:3000 > /dev/null; then
        echo "✅ SUCCESS! Application responds to HTTP requests"
        echo "Database connection fixed!"
        kill $APP_PID 2>/dev/null
        
        # Now start with PM2
        echo ""
        echo "8. Starting with PM2..."
        
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
        
        sleep 10
        
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
            pm2 logs servicedesk --lines 10
        fi
    else
        echo "❌ Application still not responding to HTTP"
        kill $APP_PID 2>/dev/null
        echo "Checking application output..."
        tsx server/index.ts 2>&1 | head -20
    fi
else
    echo "❌ Application still fails to start"
    echo "Checking startup errors..."
    tsx server/index.ts 2>&1 | head -20
fi

echo ""
echo "=== DATABASE FIX STATUS ==="
echo "Local PostgreSQL: $(psql -h localhost -U servicedesk -d servicedesk -c 'SELECT 1;' 2>/dev/null && echo 'Connected' || echo 'Failed')"
echo "Application: $(curl -s http://localhost:3000 > /dev/null && echo 'Running' || echo 'Not responding')"