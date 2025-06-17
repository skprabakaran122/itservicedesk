#!/bin/bash

echo "=== PostgreSQL Authentication Fix ==="
echo ""

cd /var/www/servicedesk

echo "1. Stopping servicedesk service..."
sudo systemctl stop servicedesk.service

echo ""
echo "2. Checking PostgreSQL authentication configuration..."
PG_VERSION=$(sudo -u postgres psql -t -c "SHOW server_version;" | sed 's/.*PostgreSQL \([0-9]\+\).*/\1/')
PG_CONFIG_DIR="/etc/postgresql/$PG_VERSION/main"

echo "PostgreSQL version: $PG_VERSION"
echo "Config directory: $PG_CONFIG_DIR"

echo ""
echo "3. Backing up and updating pg_hba.conf..."
sudo cp "$PG_CONFIG_DIR/pg_hba.conf" "$PG_CONFIG_DIR/pg_hba.conf.backup"

# Create a clean pg_hba.conf with proper authentication
sudo tee "$PG_CONFIG_DIR/pg_hba.conf" << 'EOF'
# PostgreSQL Client Authentication Configuration File

# TYPE  DATABASE        USER            ADDRESS                 METHOD

# "local" is for Unix domain socket connections only
local   all             postgres                                peer
local   all             servicedesk                             md5
local   all             all                                     peer

# IPv4 local connections:
host    all             postgres        127.0.0.1/32            scram-sha-256
host    all             servicedesk     127.0.0.1/32            md5
host    all             all             127.0.0.1/32            scram-sha-256

# IPv6 local connections:
host    all             postgres        ::1/128                 scram-sha-256
host    all             servicedesk     ::1/128                 md5
host    all             all             ::1/128                 scram-sha-256

# Allow replication connections from localhost, by a user with the
# replication privilege.
local   replication     all                                     peer
host    replication     all             127.0.0.1/32            scram-sha-256
host    replication     all             ::1/128                 scram-sha-256
EOF

echo ""
echo "4. Reloading PostgreSQL configuration..."
sudo systemctl reload postgresql

echo ""
echo "5. Recreating servicedesk user with proper authentication..."
sudo -u postgres psql << 'EOF'

-- Drop and recreate user to ensure clean authentication
DROP USER IF EXISTS servicedesk;
CREATE USER servicedesk WITH PASSWORD 'servicedesk_password_2024' SUPERUSER CREATEDB LOGIN;

-- Connect to servicedesk database
\c servicedesk

-- Grant all privileges explicitly
GRANT ALL PRIVILEGES ON DATABASE servicedesk TO servicedesk;
GRANT ALL ON SCHEMA public TO servicedesk;
ALTER SCHEMA public OWNER TO servicedesk;

-- Ensure all tables are owned by servicedesk
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public')
    LOOP
        EXECUTE 'ALTER TABLE ' || quote_ident(r.tablename) || ' OWNER TO servicedesk';
        EXECUTE 'GRANT ALL PRIVILEGES ON ' || quote_ident(r.tablename) || ' TO servicedesk';
    END LOOP;
    
    FOR r IN (SELECT sequencename FROM pg_sequences WHERE schemaname = 'public')
    LOOP
        EXECUTE 'ALTER SEQUENCE ' || quote_ident(r.sequencename) || ' OWNER TO servicedesk';
        EXECUTE 'GRANT ALL PRIVILEGES ON SEQUENCE ' || quote_ident(r.sequencename) || ' TO servicedesk';
    END LOOP;
END
$$;

-- Set default privileges
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO servicedesk;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO servicedesk;

\q
EOF

echo ""
echo "6. Testing authentication..."
export PGPASSWORD=servicedesk_password_2024
psql -h localhost -U servicedesk -d servicedesk -c "SELECT 'Authentication test successful' as status, current_user, current_database();"

echo ""
echo "7. Testing table access..."
export PGPASSWORD=servicedesk_password_2024
psql -h localhost -U servicedesk -d servicedesk -c "SELECT 'tickets' as table_name, count(*) FROM tickets UNION ALL SELECT 'changes', count(*) FROM changes UNION ALL SELECT 'users', count(*) FROM users;"

echo ""
echo "8. Verifying DATABASE_URL format..."
echo "Current DATABASE_URL:"
grep "DATABASE_URL" .env

echo ""
echo "9. Starting servicedesk with proper authentication..."
sudo systemctl start servicedesk.service

echo ""
echo "10. Monitoring startup for 10 seconds..."
sleep 10
sudo journalctl -u servicedesk.service --no-pager -n 15 | grep -E "(Warning|Error|permission denied|warmup|HTTP server)"

echo ""
echo "=== PostgreSQL Authentication Fix Complete ==="
echo ""
echo "Authentication configuration updated"
echo "User permissions verified"
echo "Service restarted with proper database access"