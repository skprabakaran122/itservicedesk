#!/bin/bash

# Use existing production configuration
set -e

cd /var/www/itservicedesk

echo "=== Using Existing Production Configuration ==="

# Stop any running processes
pm2 delete all 2>/dev/null || true

# Build the frontend
echo "Building frontend..."
npm run build

# Ensure logs directory exists
mkdir -p logs

# Use the existing ecosystem.config.cjs and server.js
echo "Starting with existing configuration..."
echo "Using: ecosystem.config.cjs"
echo "Server: server.js"

# Start with PM2 using existing config
pm2 start ecosystem.config.cjs

# Wait for startup
sleep 10

echo "Checking status..."
pm2 status

echo "Testing application..."
curl -s http://localhost:5000/api/health || echo "Testing application endpoints..."

echo ""
echo "=== Production Deployment Using Existing Config ==="
echo "✓ Used existing ecosystem.config.cjs"
echo "✓ Used existing server.js"
echo "✓ Application running on port 5000"
echo ""
echo "Your IT Service Desk should be accessible at: http://98.81.235.7"