#!/bin/bash

# Get full error logs and fix the application

echo "=== Getting Full Error Logs ==="

# Stop the service to prevent spam
sudo systemctl stop servicedesk.service

echo "Full recent logs:"
sudo journalctl -u servicedesk.service --no-pager -n 50

echo ""
echo "=== Testing Manual Execution ==="
cd /var/www/servicedesk

echo "Current environment variables:"
sudo -u www-data env | grep -E "(NODE_ENV|DATABASE_URL|PORT)"

echo ""
echo "Testing manual execution with full output:"
sudo -u www-data NODE_ENV=production PORT=5000 tsx server/index.ts

echo ""
echo "If that failed, trying with different approach..."
sudo -u www-data NODE_ENV=production DATABASE_URL="$(cat .env | grep DATABASE_URL | cut -d= -f2-)" tsx server/index.ts