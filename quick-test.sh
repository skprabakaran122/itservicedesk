#!/bin/bash

echo "Quick Test - Ubuntu Server Status"
echo "================================"

cat << 'EOF'
# Run on Ubuntu server to test current status:

cd /var/www/itservicedesk

echo "Testing port 5000 response..."
curl -s http://localhost:5000/api/auth/me

echo ""
echo "Testing authentication..."
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.user","password":"password123"}' \
  -s

echo ""
echo "Testing external HTTPS..."
curl -k -s https://98.81.235.7/api/auth/me

echo ""
echo "PM2 status:"
pm2 status

echo ""
echo "Application logs:"
pm2 logs servicedesk --lines 3

echo ""
echo "Port check:"
ss -tlnp | grep :5000

EOF