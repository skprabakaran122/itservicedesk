#!/bin/bash

echo "Testing Current Ubuntu Server State"
echo "================================="

cat << 'EOF'
# Test current state on Ubuntu server:

cd /var/www/itservicedesk

# Check if application is responding on port 5000
echo "Testing port 5000..."
curl -v http://localhost:5000/api/auth/me 2>&1 | head -10

echo ""
echo "Testing authentication..."
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.user","password":"password123"}' \
  -v

echo ""
echo "Testing HTTPS external access..."
curl -k https://98.81.235.7/api/auth/me -v 2>&1 | head -10

echo ""
echo "PM2 status:"
pm2 status

echo ""
echo "Recent logs:"
pm2 logs servicedesk --lines 10

echo ""
echo "Port status:"
netstat -tlnp | grep :5000 || ss -tlnp | grep :5000

EOF