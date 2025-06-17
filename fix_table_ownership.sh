#!/bin/bash

echo "=== Fixing Individual Table Ownership ==="
echo ""

cd /var/www/servicedesk

echo "1. Transferring ownership of all tables individually..."
sudo -u postgres psql servicedesk << 'EOF'

-- List all tables and transfer ownership
DO $$
DECLARE
    r RECORD;
BEGIN
    -- Transfer ownership of all tables
    FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public')
    LOOP
        EXECUTE 'ALTER TABLE ' || quote_ident(r.tablename) || ' OWNER TO servicedesk';
        RAISE NOTICE 'Changed owner of table % to servicedesk', r.tablename;
    END LOOP;
    
    -- Transfer ownership of all sequences
    FOR r IN (SELECT sequencename FROM pg_sequences WHERE schemaname = 'public')
    LOOP
        EXECUTE 'ALTER SEQUENCE ' || quote_ident(r.sequencename) || ' OWNER TO servicedesk';
        RAISE NOTICE 'Changed owner of sequence % to servicedesk', r.sequencename;
    END LOOP;
END
$$;

-- Grant all privileges explicitly
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO servicedesk;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO servicedesk;
GRANT USAGE, CREATE ON SCHEMA public TO servicedesk;

-- Set default privileges for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO servicedesk;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO servicedesk;

-- Make servicedesk superuser temporarily for migration
ALTER USER servicedesk WITH SUPERUSER;

-- List table ownership
\dt

\q
EOF

echo ""
echo "2. Testing table ownership..."
sudo -u www-data bash -c 'source .env && psql "$DATABASE_URL" -c "SELECT tablename, tableowner FROM pg_tables WHERE schemaname = '\''public'\'';"'

echo ""
echo "3. Running database migration with superuser privileges..."
sudo -u www-data npm run db:push

echo ""
echo "4. Removing superuser privileges after migration..."
sudo -u postgres psql servicedesk << 'EOF'
-- Remove superuser privileges
ALTER USER servicedesk WITH NOSUPERUSER;
\q
EOF

echo ""
echo "=== Table Ownership Fix Complete ==="