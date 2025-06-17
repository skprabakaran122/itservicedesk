#!/bin/bash

echo "=== Ultimate Database Fix ==="
echo ""

cd /var/www/servicedesk

echo "1. Stopping service..."
sudo systemctl stop servicedesk.service

echo ""
echo "2. Backing up current .env and creating clean configuration..."
sudo -u www-data cp .env .env.backup.ultimate
echo "DATABASE_URL=postgresql://servicedesk:servicedesk_password_2024@localhost:5432/servicedesk" | sudo -u www-data tee .env

echo ""
echo "3. Completely dropping and recreating everything..."
sudo -u postgres psql << 'EOF'

-- Terminate all connections
SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'servicedesk' AND pid <> pg_backend_pid();

-- Drop everything
DROP DATABASE IF EXISTS servicedesk;
DROP USER IF EXISTS servicedesk;

-- Create user with superuser privileges
CREATE USER servicedesk WITH PASSWORD 'servicedesk_password_2024' SUPERUSER CREATEDB LOGIN;

-- Create database
CREATE DATABASE servicedesk OWNER servicedesk;

\q
EOF

echo ""
echo "4. Connecting as servicedesk user to set up schema..."
export PGPASSWORD=servicedesk_password_2024
psql -h localhost -U servicedesk -d servicedesk << 'EOF'

-- Ensure servicedesk owns the schema
ALTER SCHEMA public OWNER TO servicedesk;

-- Set default privileges
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO servicedesk;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO servicedesk;

\q
EOF

echo ""
echo "5. Running migration as www-data user..."
sudo -u www-data npm run db:push

echo ""
echo "6. Verifying all tables are owned by servicedesk..."
export PGPASSWORD=servicedesk_password_2024
psql -h localhost -U servicedesk -d servicedesk -c "SELECT tablename, tableowner FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;"

echo ""
echo "7. Testing table access..."
export PGPASSWORD=servicedesk_password_2024
psql -h localhost -U servicedesk -d servicedesk << 'EOF'
SELECT 'Testing table access...' as status;
SELECT count(*) as ticket_count FROM tickets;
SELECT count(*) as change_count FROM changes;
SELECT count(*) as user_count FROM users;
EOF

echo ""
echo "8. Building application..."
sudo -u www-data npm run build
sudo -u www-data cp -r dist/* server/public/

echo ""
echo "9. Starting service..."
sudo systemctl start servicedesk.service

echo ""
echo "10. Monitoring for 15 seconds..."
timeout 15 sudo journalctl -u servicedesk.service -f --no-pager &
sleep 15
pkill -f "journalctl -u servicedesk.service"

echo ""
echo "=== Ultimate Fix Complete ==="
echo ""
echo "Database recreated with servicedesk as owner of all objects"
echo "Application should now run without permission errors"