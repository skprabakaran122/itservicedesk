#!/bin/bash

echo "=== Complete Database Rebuild Solution ==="
echo ""

cd /var/www/servicedesk

echo "1. Stopping servicedesk service..."
sudo systemctl stop servicedesk.service

echo ""
echo "2. Completely removing and recreating database..."
sudo -u postgres psql << 'EOF'

-- Terminate all connections to the database
SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'servicedesk' AND pid <> pg_backend_pid();

-- Drop database completely
DROP DATABASE IF EXISTS servicedesk;

-- Drop user completely
DROP USER IF EXISTS servicedesk;

-- Create user with all necessary privileges
CREATE USER servicedesk WITH PASSWORD 'servicedesk_password_2024' CREATEDB SUPERUSER LOGIN;

-- Create database owned by servicedesk
CREATE DATABASE servicedesk OWNER servicedesk;

-- Connect to database and set up permissions
\c servicedesk

-- Grant all privileges on database
GRANT ALL PRIVILEGES ON DATABASE servicedesk TO servicedesk;

-- Grant schema permissions
GRANT ALL ON SCHEMA public TO servicedesk;
ALTER SCHEMA public OWNER TO servicedesk;

-- Set default privileges for all future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO servicedesk;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO servicedesk;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO servicedesk;

\q
EOF

echo ""
echo "3. Verifying clean database state..."
sudo -u postgres psql -l | grep servicedesk

echo ""
echo "4. Testing servicedesk user connection..."
export PGPASSWORD=servicedesk_password_2024
psql -h localhost -U servicedesk -d servicedesk -c "SELECT current_user, current_database();"

echo ""
echo "5. Running database migration on completely clean database..."
sudo -u www-data npm run db:push

if [ $? -ne 0 ]; then
    echo "Migration failed. Checking what went wrong..."
    exit 1
fi

echo ""
echo "6. Verifying table ownership after migration..."
export PGPASSWORD=servicedesk_password_2024
psql -h localhost -U servicedesk -d servicedesk -c "SELECT schemaname, tablename, tableowner FROM pg_tables WHERE schemaname = 'public';"

echo ""
echo "7. Testing table access..."
export PGPASSWORD=servicedesk_password_2024
psql -h localhost -U servicedesk -d servicedesk << 'EOF'
-- Test each table access
SELECT 'tickets' as table_name, count(*) as count FROM tickets
UNION ALL
SELECT 'changes' as table_name, count(*) as count FROM changes
UNION ALL
SELECT 'users' as table_name, count(*) as count FROM users;
EOF

echo ""
echo "8. Building and deploying application..."
sudo -u www-data npm run build
sudo -u www-data mkdir -p server/public
sudo -u www-data cp -r dist/* server/public/

echo ""
echo "9. Starting servicedesk service..."
sudo systemctl start servicedesk.service

echo ""
echo "10. Monitoring startup for 10 seconds..."
timeout 10 sudo journalctl -u servicedesk.service -f --no-pager | grep -E "(Warning|Error|HTTP server|Database|permission denied|warmup|SLA|AUTO-CLOSE|OVERDUE)" || true

echo ""
echo "=== Complete Database Rebuild Finished ==="
echo ""
echo "Database completely recreated with servicedesk as owner"
echo "All tables should now have proper ownership"
echo "Permission errors should be eliminated"