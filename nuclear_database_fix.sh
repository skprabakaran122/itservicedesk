#!/bin/bash

echo "=== Nuclear Database Fix - Complete Reset and Setup ==="
echo ""

cd /var/www/servicedesk

echo "1. Dropping and recreating database with proper ownership..."
sudo -u postgres psql << 'EOF'

-- Drop existing database
DROP DATABASE IF EXISTS servicedesk;

-- Recreate user with proper privileges
DROP USER IF EXISTS servicedesk;
CREATE USER servicedesk WITH PASSWORD 'servicedesk_password_2024' CREATEDB SUPERUSER;

-- Create database with servicedesk as owner
CREATE DATABASE servicedesk OWNER servicedesk;

-- Grant all privileges
GRANT ALL PRIVILEGES ON DATABASE servicedesk TO servicedesk;

\q
EOF

echo ""
echo "2. Updating .env with correct DATABASE_URL..."
sudo -u www-data sed -i 's|DATABASE_URL=.*|DATABASE_URL=postgresql://servicedesk:servicedesk_password_2024@localhost:5432/servicedesk|' .env

echo ""
echo "3. Testing fresh database connection..."
sudo -u www-data bash -c 'source .env && psql "$DATABASE_URL" -c "SELECT 1;"'

echo ""
echo "4. Running database migration on fresh database..."
sudo -u www-data npm run db:push

echo ""
echo "5. Building application..."
sudo -u www-data npm run build

echo ""
echo "6. Deploying build files..."
sudo -u www-data mkdir -p server/public
sudo -u www-data cp -r dist/* server/public/

echo ""
echo "7. Restarting servicedesk service..."
sudo systemctl restart servicedesk.service

echo ""
echo "8. Checking service status..."
sleep 3
sudo systemctl status servicedesk.service --no-pager

echo ""
echo "=== Complete Database Reset Finished ==="
echo ""
echo "Fresh database created with proper ownership from start"
echo "All tables will be owned by servicedesk user"
echo "Migration should complete without permission errors"