#!/bin/bash

echo "=== Fixing Database Permissions ==="
echo ""

cd /var/www/servicedesk

echo "1. Connecting as postgres superuser to fix permissions..."
sudo -u postgres psql << 'EOF'

-- Connect to servicedesk database
\c servicedesk

-- Grant all privileges on database
GRANT ALL PRIVILEGES ON DATABASE servicedesk TO servicedesk;

-- Grant all privileges on all existing tables
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO servicedesk;

-- Grant all privileges on all existing sequences
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO servicedesk;

-- Grant all privileges on all existing functions
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO servicedesk;

-- Grant usage on schema
GRANT USAGE ON SCHEMA public TO servicedesk;

-- Set default privileges for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO servicedesk;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO servicedesk;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO servicedesk;

-- Make servicedesk owner of the database
ALTER DATABASE servicedesk OWNER TO servicedesk;

-- Transfer ownership of all existing objects
REASSIGN OWNED BY postgres TO servicedesk;

-- List current tables and their owners
\dt

-- Quit
\q
EOF

echo ""
echo "2. Testing database permissions..."
sudo -u www-data bash -c 'source .env && psql "$DATABASE_URL" -c "CREATE TABLE test_permissions (id SERIAL PRIMARY KEY); DROP TABLE test_permissions;"'

if [ $? -eq 0 ]; then
    echo "✓ Database permissions test successful"
else
    echo "✗ Database permissions test failed"
fi

echo ""
echo "3. Running database migration..."
sudo -u www-data npm run db:push

echo ""
echo "=== Database Permissions Fix Complete ==="