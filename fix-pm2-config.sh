#!/bin/bash
cd /var/www/itservicedesk

# Create the correct PM2 config file
cat > production-adapter-fixed.config.cjs << 'CONFIG_EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'production-adapter-fixed.cjs',
    instances: 1,
    autorestart: true,
    max_restarts: 5,
    restart_delay: 3000,
    env: {
      NODE_ENV: 'production',
      PORT: 5000,
      DATABASE_URL: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk',
      SESSION_SECRET: 'calpion-service-desk-secret-key-2025'
    },
    error_file: '/tmp/servicedesk-error.log',
    out_file: '/tmp/servicedesk-out.log',
    log_file: '/tmp/servicedesk-combined.log',
    merge_logs: true,
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z'
  }]
};
CONFIG_EOF

# Start the fixed server
pm2 delete servicedesk 2>/dev/null
pm2 start production-adapter-fixed.config.cjs
pm2 save

sleep 20

# Test that it's working
echo "Testing server status:"
curl -s http://localhost:5000/health

echo -e "\nTesting authentication:"
JOHN_AUTH=$(curl -s -c /tmp/cookies.txt -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"john.doe","password":"password123"}')
echo "$JOHN_AUTH"

echo -e "\nTesting product creation:"
CREATE_PRODUCT=$(curl -s -b /tmp/cookies.txt -X POST http://localhost:5000/api/products \
  -H "Content-Type: application/json" \
  -d '{"name":"Test Product","description":"Testing fixed server","category":"software"}')
echo "$CREATE_PRODUCT"

echo -e "\nPM2 status:"
pm2 status

if echo "$JOHN_AUTH" | grep -q '"user"' && echo "$CREATE_PRODUCT" | grep -q '"name"'; then
    echo -e "\nSUCCESS: Server is running and product creation works!"
    echo "Access: https://98.81.235.7"
else
    echo -e "\nChecking logs:"
    pm2 logs servicedesk --lines 10
fi

rm -f /tmp/cookies.txt
