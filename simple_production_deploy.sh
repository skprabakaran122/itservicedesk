#!/bin/bash

# Simple Production Deployment - Run dev mode on production server
echo "Starting production deployment..."

# Stop existing processes
pm2 stop all 2>/dev/null || true
pm2 delete all 2>/dev/null || true

# Install dependencies
npm install

# Setup database
npm run db:push

# Create logs directory
mkdir -p logs

# Start application in development mode (works reliably)
pm2 start npm \
    --name servicedesk \
    -- run dev \
    --env NODE_ENV=production \
    --env PORT=5000

# Save configuration
pm2 save

# Display status
pm2 status
pm2 logs servicedesk --lines 5

echo "Deployment complete. Application available at: http://54.160.177.174:5000"