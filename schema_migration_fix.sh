#!/bin/bash

echo "=== Schema Migration Fix ==="
echo ""

cd /var/www/servicedesk

echo "1. Stopping service..."
sudo systemctl stop servicedesk.service

echo ""
echo "2. Checking current database schema..."
export PGPASSWORD=servicedesk_password_2024
psql -h localhost -U servicedesk -d servicedesk -c "\d users"

echo ""
echo "3. Running Drizzle schema migration..."
sudo -u www-data npm run db:push

echo ""
echo "4. Verifying schema after migration..."
export PGPASSWORD=servicedesk_password_2024
psql -h localhost -U servicedesk -d servicedesk -c "\d users"

echo ""
echo "5. Testing all table schemas..."
export PGPASSWORD=servicedesk_password_2024
psql -h localhost -U servicedesk -d servicedesk << 'EOF'
-- Check all critical tables exist and have proper structure
\d tickets
\d changes  
\d users
\d products
\d attachments
EOF

echo ""
echo "6. Creating test data to verify full functionality..."
export PGPASSWORD=servicedesk_password_2024
psql -h localhost -U servicedesk -d servicedesk << 'EOF'
-- Insert test user with correct schema
INSERT INTO users (username, email, hashedPassword, role) 
VALUES ('test_user', 'test@example.com', 'test_hash', 'user')
ON CONFLICT (username) DO UPDATE SET email = EXCLUDED.email;

-- Verify the insert worked
SELECT username, email, role FROM users WHERE username = 'test_user';

-- Clean up test data
DELETE FROM users WHERE username = 'test_user';
EOF

echo ""
echo "7. Building application with updated schema..."
sudo -u www-data npm run build
sudo -u www-data cp -r dist/* server/public/

echo ""
echo "8. Starting service..."
sudo systemctl start servicedesk.service

echo ""
echo "9. Monitoring for schema-related errors..."
sleep 10
sudo journalctl -u servicedesk.service --no-pager -n 10 | grep -E "(permission denied|Error|Warning|column.*does not exist|warmup|HTTP server)"

echo ""
echo "=== Schema Migration Complete ==="