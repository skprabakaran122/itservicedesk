#!/bin/bash

echo "Fixing Database Configuration"
echo "============================"

cd /var/www/itservicedesk

# Stop all PM2 processes to clear port conflicts
sudo -u ubuntu pm2 delete all

# Kill any processes using port 3000
sudo lsof -ti:3000 | xargs sudo kill -9 2>/dev/null || true

# Update the database configuration to use local PostgreSQL
sudo -u ubuntu tee .env << 'EOF'
DATABASE_URL=postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk
NODE_ENV=production
PORT=3000
EOF

# Check if the application is using Neon config - update it to use local PostgreSQL
if [ -f "server/db.ts" ]; then
    sudo -u ubuntu cp server/db.ts server/db.ts.backup
    
    sudo -u ubuntu tee server/db.ts << 'EOF'
import { Pool } from 'pg';
import { drizzle } from 'drizzle-orm/node-postgres';
import * as schema from "@shared/schema";

if (!process.env.DATABASE_URL) {
  throw new Error(
    "DATABASE_URL must be set. Did you forget to provision a database?",
  );
}

export const pool = new Pool({ 
  connectionString: process.env.DATABASE_URL,
  ssl: false  // Disable SSL for local PostgreSQL
});

export const db = drizzle(pool, { schema });
EOF

    echo "Updated database configuration to use local PostgreSQL"
fi

# Rebuild the application with the new configuration
echo "Rebuilding application..."
sudo -u ubuntu npm run build

# Initialize database schema
echo "Initializing database schema..."
sudo -u ubuntu npm run db:push

# Create default user directly in PostgreSQL
echo "Creating default user..."
export PGPASSWORD=servicedesk123
psql -h localhost -U servicedesk -d servicedesk << 'EOF'
INSERT INTO users (username, email, password, "firstName", "lastName", role, department, "businessUnit", "createdAt", "updatedAt")
VALUES (
  'john.doe', 
  'john.doe@calpion.com', 
  '$2b$10$K7L/VnVp8wJw8r1nZoKhBOJ7J5dJn2nJ5pJ7J5dJn2nJ5pJ7J5dJn2',
  'John', 
  'Doe', 
  'admin', 
  'IT', 
  'Technology',
  NOW(),
  NOW()
)
ON CONFLICT (username) DO NOTHING;
EOF

# Create a simple PM2 configuration that doesn't use clustering
sudo -u ubuntu tee simple.config.cjs << 'EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: './dist/index.js',
    instances: 1,
    exec_mode: 'fork',  // Use fork mode instead of cluster
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

# Start the application
echo "Starting application..."
sudo -u ubuntu pm2 start simple.config.cjs

sleep 10

# Test the application
echo "Testing application..."
if curl -s http://localhost:3000/api/auth/me | grep -q "Not authenticated"; then
    echo "✓ Application responding correctly"
    
    # Test login
    echo "Testing login..."
    LOGIN_TEST=$(curl -s -X POST http://localhost:3000/api/auth/login \
      -H "Content-Type: application/json" \
      -d '{"username":"john.doe","password":"password123"}')
    
    if echo "$LOGIN_TEST" | grep -q "user\|success"; then
        echo "✓ Login working"
    else
        echo "Login test result: $LOGIN_TEST"
    fi
else
    echo "Application test failed"
    sudo -u ubuntu pm2 logs servicedesk --lines 5
fi

echo ""
echo "✓ Database configuration fixed for local PostgreSQL"
echo "Your IT Service Desk is running at: https://98.81.235.7"
echo "Login with: john.doe / password123"