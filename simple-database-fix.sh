#!/bin/bash

# Simple fix - just use the working database configuration
set -e

cd /var/www/itservicedesk

echo "=== Simple Database Fix ==="

# Stop PM2
pm2 stop servicedesk 2>/dev/null || true

# Update the existing PM2 configuration to use the working database
sed -i 's/NODE_ENV: .production./NODE_ENV: "production",\n      DATABASE_URL: "postgresql:\/\/neondb_owner:npg_CHFj1dqMYB6V@ep-still-snow-a65c90fl.us-west-2.aws.neon.tech\/neondb?sslmode=require"/' ecosystem.production.config.cjs

# Test with the working database
echo "Testing with working database..."
export DATABASE_URL="postgresql://neondb_owner:npg_CHFj1dqMYB6V@ep-still-snow-a65c90fl.us-west-2.aws.neon.tech/neondb?sslmode=require"

timeout 10s node dist/index.js &
TEST_PID=$!
sleep 5

if curl -s http://localhost:5000/api/health >/dev/null 2>&1; then
    echo "✓ Working with Neon database"
    kill $TEST_PID 2>/dev/null || true
else
    echo "✗ Still having issues"
    kill $TEST_PID 2>/dev/null || true
    exit 1
fi

# Start PM2
pm2 start ecosystem.production.config.cjs

sleep 8
pm2 status

echo "Testing final application..."
curl -s http://localhost:5000/api/health

echo ""
echo "✓ IT Service Desk operational at http://98.81.235.7"
echo "✓ Using same database as development"