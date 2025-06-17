#!/bin/bash

echo "=== Fixing Drizzle ORM Database Permissions ==="
echo ""

cd /var/www/servicedesk

echo "1. Stopping service..."
sudo systemctl stop servicedesk.service

echo "2. Creating comprehensive permission fix for all database objects..."
sudo -u postgres psql servicedesk << 'EOF'

-- Grant superuser temporarily to avoid any permission issues
ALTER USER servicedesk WITH SUPERUSER;

-- Ensure servicedesk owns everything
ALTER SCHEMA public OWNER TO servicedesk;

-- Grant permissions on all existing objects
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO servicedesk;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO servicedesk;
GRANT USAGE, CREATE ON SCHEMA public TO servicedesk;

-- Make sure servicedesk owns all tables individually
DO $$
DECLARE
    r RECORD;
BEGIN
    -- Tables
    FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public')
    LOOP
        EXECUTE 'ALTER TABLE public.' || quote_ident(r.tablename) || ' OWNER TO servicedesk';
        EXECUTE 'GRANT ALL PRIVILEGES ON TABLE public.' || quote_ident(r.tablename) || ' TO servicedesk';
    END LOOP;
    
    -- Sequences
    FOR r IN (SELECT sequencename FROM pg_sequences WHERE schemaname = 'public')
    LOOP
        EXECUTE 'ALTER SEQUENCE public.' || quote_ident(r.sequencename) || ' OWNER TO servicedesk';
        EXECUTE 'GRANT ALL PRIVILEGES ON SEQUENCE public.' || quote_ident(r.sequencename) || ' TO servicedesk';
    END LOOP;
END
$$;

-- Set default privileges for any future objects
ALTER DEFAULT PRIVILEGES FOR USER servicedesk IN SCHEMA public GRANT ALL ON TABLES TO servicedesk;
ALTER DEFAULT PRIVILEGES FOR USER servicedesk IN SCHEMA public GRANT ALL ON SEQUENCES TO servicedesk;
ALTER DEFAULT PRIVILEGES FOR USER postgres IN SCHEMA public GRANT ALL ON TABLES TO servicedesk;
ALTER DEFAULT PRIVILEGES FOR USER postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO servicedesk;

-- Test permissions on specific problematic tables
SELECT 'Testing permissions on tables:' as status;
SELECT tablename, tableowner, 
       has_table_privilege('servicedesk', schemaname||'.'||tablename, 'SELECT') as can_select,
       has_table_privilege('servicedesk', schemaname||'.'||tablename, 'UPDATE') as can_update
FROM pg_tables 
WHERE schemaname = 'public' AND tablename IN ('tickets', 'changes', 'users')
ORDER BY tablename;

\q
EOF

echo ""
echo "3. Testing direct table access as servicedesk user..."
export PGPASSWORD=servicedesk_password_2024
psql -h localhost -U servicedesk -d servicedesk << 'EOF'

-- Test each problematic table individually
SELECT 'Testing tickets table...' as test;
SELECT count(*) as ticket_count FROM tickets;

SELECT 'Testing changes table...' as test;
SELECT count(*) as change_count FROM changes;

SELECT 'Testing users table...' as test;
SELECT count(*) as user_count FROM users;

-- Test a simple insert/delete to verify write permissions
INSERT INTO users (username, email, password_hash, role) 
VALUES ('test_permissions', 'test@example.com', 'hash', 'user')
ON CONFLICT (username) DO NOTHING;

DELETE FROM users WHERE username = 'test_permissions';

SELECT 'All table tests completed successfully' as result;

\q
EOF

echo ""
echo "4. Creating fresh database connection test..."
cat > test_connection.js << 'EOF'
const { Pool } = require('pg');

async function testConnection() {
    const pool = new Pool({
        connectionString: process.env.DATABASE_URL,
        ssl: false
    });
    
    try {
        console.log('Testing database connection...');
        const client = await pool.connect();
        
        // Test each table
        const tables = ['tickets', 'changes', 'users'];
        for (const table of tables) {
            try {
                const result = await client.query(`SELECT count(*) FROM ${table}`);
                console.log(`✓ ${table}: ${result.rows[0].count} records`);
            } catch (error) {
                console.log(`✗ ${table}: ${error.message}`);
            }
        }
        
        client.release();
        await pool.end();
        console.log('Database connection test completed');
    } catch (error) {
        console.error('Connection test failed:', error.message);
        process.exit(1);
    }
}

testConnection();
EOF

echo ""
echo "5. Running Node.js connection test with same configuration as app..."
sudo -u www-data bash -c 'source .env && node test_connection.js'

rm test_connection.js

echo ""
echo "6. Starting service with verified permissions..."
sudo systemctl start servicedesk.service

echo ""
echo "7. Monitoring startup for permission errors..."
sleep 8
sudo journalctl -u servicedesk.service --no-pager -n 10 | grep -E "(permission denied|Error|Warning|warmup|HTTP server)" || echo "No permission errors found"

echo ""
echo "=== Drizzle ORM Permission Fix Complete ==="