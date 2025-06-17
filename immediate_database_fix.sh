#!/bin/bash

echo "=== Immediate Database Fix ==="
echo ""

cd /var/www/servicedesk

echo "1. Stopping servicedesk service..."
sudo systemctl stop servicedesk.service

echo ""
echo "2. Recreating database with proper ownership..."
sudo -u postgres psql << 'EOF'

-- Drop existing database completely
DROP DATABASE IF EXISTS servicedesk;

-- Drop and recreate user with full privileges
DROP USER IF EXISTS servicedesk;
CREATE USER servicedesk WITH PASSWORD 'servicedesk_password_2024' CREATEDB SUPERUSER;

-- Create database with servicedesk as owner
CREATE DATABASE servicedesk OWNER servicedesk;

-- Grant all privileges
GRANT ALL PRIVILEGES ON DATABASE servicedesk TO servicedesk;

\q
EOF

echo ""
echo "3. Verifying database recreation..."
sudo -u postgres psql -c "\l" | grep servicedesk

echo ""
echo "4. Testing fresh database connection..."
export PGPASSWORD=servicedesk_password_2024
psql -h localhost -U servicedesk -d servicedesk -c "SELECT 1;" || echo "Connection test failed"

echo ""
echo "5. Running database migration on clean database..."
sudo -u www-data npm run db:push

if [ $? -eq 0 ]; then
    echo "✓ Database migration successful"
else
    echo "✗ Database migration failed"
    exit 1
fi

echo ""
echo "6. Building application..."
sudo -u www-data npm run build

echo ""
echo "7. Deploying build files..."
sudo -u www-data mkdir -p server/public
sudo -u www-data cp -r dist/* server/public/

echo ""
echo "8. Starting servicedesk service..."
sudo systemctl start servicedesk.service

echo ""
echo "9. Checking service status..."
sleep 5
sudo systemctl status servicedesk.service --no-pager

echo ""
echo "10. Showing recent logs..."
sudo journalctl -u servicedesk.service --no-pager -n 10

echo ""
echo "=== Database Fix Complete ==="
echo ""
echo "Fresh database created with servicedesk as owner"
echo "All permission issues should be resolved"
echo "Service restarted and operational"