#!/bin/bash

# Direct PM2 fix using the .cjs config file that already exists
cd /var/www/itservicedesk

# Stop all PM2 processes
pm2 stop all 2>/dev/null || true
pm2 delete all 2>/dev/null || true
pm2 kill

# Set environment variables
export DATABASE_URL="postgresql://ubuntu:password@localhost:5432/servicedesk"
export NODE_ENV="production"
export PORT="5000"

# Ensure production file exists
cp server/production.cjs dist/production.cjs

# Start using the existing .cjs config
pm2 start ecosystem.config.cjs

# Wait and test
sleep 10

# Check status
pm2 status

# Test application
curl -s http://localhost:5000/health