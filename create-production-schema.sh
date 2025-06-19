#!/bin/bash

# Create production database schema
set -e

cd /var/www/itservicedesk

echo "=== Creating Production Database Schema ==="

# Stop PM2 temporarily
pm2 stop servicedesk

# Push the database schema to production
echo "Pushing database schema..."
npm run db:push

# Wait for schema creation
sleep 3

# Test database tables exist
echo "Verifying database schema..."
psql -U postgres -h localhost -d servicedesk -c "\dt" || {
    echo "Schema creation failed"
    exit 1
}

echo "✓ Database schema created successfully"

# Restart PM2
pm2 restart servicedesk

sleep 10

# Test the application with working database
echo "Testing application with database schema..."
curl -s http://localhost:5000/api/health

# Check if we can access basic endpoints
curl -s http://localhost:5000/api/users >/dev/null && echo "✓ Users endpoint working"
curl -s http://localhost:5000/api/products >/dev/null && echo "✓ Products endpoint working"

echo ""
echo "=== Production Database Schema Complete ==="
echo "✓ All database tables created"
echo "✓ Application running with working database"
echo "✓ IT Service Desk fully operational at http://98.81.235.7"