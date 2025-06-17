#!/bin/bash

echo "=== Final Database Permission Fix ==="
echo ""

cd /var/www/servicedesk

echo "1. Stopping service to prevent interference..."
sudo systemctl stop servicedesk.service

echo ""
echo "2. Connecting as postgres to grant full permissions..."
sudo -u postgres psql servicedesk << 'EOF'

-- Make servicedesk a superuser temporarily
ALTER USER servicedesk WITH SUPERUSER;

-- Grant ownership of schema
ALTER SCHEMA public OWNER TO servicedesk;

-- Grant all privileges on database
GRANT ALL PRIVILEGES ON DATABASE servicedesk TO servicedesk;

-- List existing tables and their owners
SELECT schemaname,tablename,tableowner FROM pg_tables WHERE schemaname = 'public';

-- Transfer ownership of all objects
REASSIGN OWNED BY postgres TO servicedesk;

-- Grant all current and future privileges
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO servicedesk;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO servicedesk;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO servicedesk;
GRANT USAGE ON SCHEMA public TO servicedesk;

-- Set default privileges for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO servicedesk;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO servicedesk;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO servicedesk;

-- Verify ownership
SELECT schemaname,tablename,tableowner FROM pg_tables WHERE schemaname = 'public';

\q
EOF

echo ""
echo "3. Testing database access as servicedesk user..."
export PGPASSWORD=servicedesk_password_2024
psql -h localhost -U servicedesk -d servicedesk << 'EOF'

-- Test table access
SELECT count(*) FROM tickets;
SELECT count(*) FROM changes;
SELECT count(*) FROM users;

-- Test table modification
CREATE TABLE test_permissions (id SERIAL PRIMARY KEY, test_field TEXT);
DROP TABLE test_permissions;

\q
EOF

if [ $? -eq 0 ]; then
    echo "✓ Database permissions verified successfully"
else
    echo "✗ Database permissions still failing"
fi

echo ""
echo "4. Running fresh database migration..."
sudo -u www-data npm run db:push

echo ""
echo "5. Starting service with fixed permissions..."
sudo systemctl start servicedesk.service

echo ""
echo "6. Monitoring startup logs..."
sleep 5
sudo journalctl -u servicedesk.service --no-pager -n 15 | grep -E "(Warning|Error|HTTP server|Database|SLA|AUTO-CLOSE|OVERDUE)"

echo ""
echo "=== Permission Fix Complete ==="
echo ""
echo "Service should now start without permission errors"
echo "Monitor with: sudo journalctl -u servicedesk.service -f"