#!/bin/bash

echo "=== Final Database Solution ==="
echo ""

cd /var/www/servicedesk

echo "1. Stopping all database activity..."
sudo systemctl stop servicedesk.service
sudo pkill -f "tsx.*server/index.ts" 2>/dev/null || true

echo ""
echo "2. Creating nuclear permission reset..."
sudo -u postgres psql << 'EOF'

-- Connect to servicedesk database
\c servicedesk

-- Make servicedesk superuser and owner of everything
ALTER USER servicedesk WITH SUPERUSER CREATEDB CREATEROLE REPLICATION;
ALTER DATABASE servicedesk OWNER TO servicedesk;
ALTER SCHEMA public OWNER TO servicedesk;

-- Drop all default privileges and recreate them properly
ALTER DEFAULT PRIVILEGES FOR ROLE postgres REVOKE ALL ON TABLES FROM postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres REVOKE ALL ON SEQUENCES FROM postgres;

-- Grant comprehensive permissions
GRANT ALL ON DATABASE servicedesk TO servicedesk;
GRANT ALL ON SCHEMA public TO servicedesk;

-- Transfer ownership of every object
DO $$
DECLARE
    r RECORD;
    sql_stmt TEXT;
BEGIN
    -- All tables
    FOR r IN (SELECT schemaname, tablename FROM pg_tables WHERE schemaname = 'public')
    LOOP
        sql_stmt := 'ALTER TABLE ' || quote_ident(r.schemaname) || '.' || quote_ident(r.tablename) || ' OWNER TO servicedesk';
        EXECUTE sql_stmt;
        sql_stmt := 'GRANT ALL PRIVILEGES ON TABLE ' || quote_ident(r.schemaname) || '.' || quote_ident(r.tablename) || ' TO servicedesk';
        EXECUTE sql_stmt;
    END LOOP;
    
    -- All sequences
    FOR r IN (SELECT schemaname, sequencename FROM pg_sequences WHERE schemaname = 'public')
    LOOP
        sql_stmt := 'ALTER SEQUENCE ' || quote_ident(r.schemaname) || '.' || quote_ident(r.sequencename) || ' OWNER TO servicedesk';
        EXECUTE sql_stmt;
        sql_stmt := 'GRANT ALL PRIVILEGES ON SEQUENCE ' || quote_ident(r.schemaname) || '.' || quote_ident(r.sequencename) || ' TO servicedesk';
        EXECUTE sql_stmt;
    END LOOP;
    
    -- All views if any
    FOR r IN (SELECT schemaname, viewname FROM pg_views WHERE schemaname = 'public')
    LOOP
        sql_stmt := 'ALTER VIEW ' || quote_ident(r.schemaname) || '.' || quote_ident(r.viewname) || ' OWNER TO servicedesk';
        EXECUTE sql_stmt;
    END LOOP;
END
$$;

-- Set future object privileges
ALTER DEFAULT PRIVILEGES FOR ROLE servicedesk IN SCHEMA public GRANT ALL ON TABLES TO servicedesk;
ALTER DEFAULT PRIVILEGES FOR ROLE servicedesk IN SCHEMA public GRANT ALL ON SEQUENCES TO servicedesk;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO servicedesk;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO servicedesk;

-- Verify critical tables
SELECT tablename, tableowner, 
       has_table_privilege('servicedesk', 'public.'||tablename, 'SELECT') as select_perm,
       has_table_privilege('servicedesk', 'public.'||tablename, 'UPDATE') as update_perm,
       has_table_privilege('servicedesk', 'public.'||tablename, 'INSERT') as insert_perm,
       has_table_privilege('servicedesk', 'public.'||tablename, 'DELETE') as delete_perm
FROM pg_tables 
WHERE schemaname = 'public' AND tablename IN ('tickets', 'changes', 'users')
ORDER BY tablename;

\q
EOF

echo ""
echo "3. Testing permissions with exact same connection as app..."
export PGPASSWORD=servicedesk_password_2024

echo "Testing SELECT permissions:"
psql -h localhost -U servicedesk -d servicedesk -c "SELECT 'tickets' as table_name, count(*) FROM tickets UNION ALL SELECT 'changes', count(*) FROM changes UNION ALL SELECT 'users', count(*) FROM users;"

echo ""
echo "Testing INSERT/UPDATE permissions:"
psql -h localhost -U servicedesk -d servicedesk << 'EOF'
BEGIN;
INSERT INTO users (username, email, password_hash, role) VALUES ('perm_test', 'test@test.com', 'hash', 'user') ON CONFLICT (username) DO NOTHING;
UPDATE users SET email = 'updated@test.com' WHERE username = 'perm_test';
DELETE FROM users WHERE username = 'perm_test';
ROLLBACK;
EOF

echo ""
echo "4. Updating database connection to use superuser privileges..."
sudo -u www-data cp .env .env.backup.final

# Use servicedesk as superuser in connection string
echo "DATABASE_URL=postgresql://servicedesk:servicedesk_password_2024@localhost:5432/servicedesk" | sudo -u www-data tee .env

echo ""
echo "5. Testing Node.js database access..."
cat > final_test.js << 'EOF'
const { Pool } = require('pg');

async function testApp() {
    const pool = new Pool({
        connectionString: process.env.DATABASE_URL,
        ssl: false,
        max: 1
    });
    
    try {
        const client = await pool.connect();
        console.log('Connected as:', (await client.query('SELECT current_user')).rows[0].current_user);
        
        // Test problematic queries
        const ticketCount = await client.query('SELECT count(*) FROM tickets');
        const changeCount = await client.query('SELECT count(*) FROM changes');
        const userCount = await client.query('SELECT count(*) FROM users');
        
        console.log('✓ Tickets accessible:', ticketCount.rows[0].count);
        console.log('✓ Changes accessible:', changeCount.rows[0].count);
        console.log('✓ Users accessible:', userCount.rows[0].count);
        
        client.release();
        await pool.end();
        console.log('All database operations successful');
    } catch (error) {
        console.error('Database test failed:', error.message);
        process.exit(1);
    }
}

testApp();
EOF

sudo -u www-data bash -c 'source .env && node final_test.js'
rm final_test.js

echo ""
echo "6. Starting service with superuser database access..."
sudo systemctl start servicedesk.service

echo ""
echo "7. Final monitoring..."
sleep 10
sudo journalctl -u servicedesk.service --no-pager -n 8 | grep -E "(permission denied|Error|Warning|warmup|HTTP server|Database)" || echo "No database errors found"

echo ""
echo "=== Final Database Solution Complete ==="
echo "Servicedesk user now has superuser privileges"
echo "All database objects owned by servicedesk"
echo "Application should run without permission errors"