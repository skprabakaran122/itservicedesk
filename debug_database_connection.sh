#!/bin/bash

echo "=== Database Connection Debug ==="
echo ""

cd /var/www/servicedesk

echo "1. Checking current DATABASE_URL in .env..."
grep "DATABASE_URL" .env

echo ""
echo "2. Testing what the application actually connects to..."
sudo -u www-data bash -c 'source .env && echo "DATABASE_URL: $DATABASE_URL"'

echo ""
echo "3. Testing connection with the exact URL from .env..."
sudo -u www-data bash -c 'source .env && psql "$DATABASE_URL" -c "SELECT current_user, current_database(), session_user;"'

echo ""
echo "4. Checking what user owns the tables..."
sudo -u www-data bash -c 'source .env && psql "$DATABASE_URL" -c "SELECT schemaname, tablename, tableowner FROM pg_tables WHERE schemaname = '\''public'\'' ORDER BY tablename;"'

echo ""
echo "5. Stopping service and manually fixing DATABASE_URL..."
sudo systemctl stop servicedesk.service

# Force update the DATABASE_URL to ensure it's correct
sudo -u www-data cp .env .env.backup.debug
echo "DATABASE_URL=postgresql://servicedesk:servicedesk_password_2024@localhost:5432/servicedesk" | sudo -u www-data tee .env

echo ""
echo "6. Verifying updated .env..."
cat .env

echo ""
echo "7. Testing connection with corrected URL..."
sudo -u www-data bash -c 'source .env && psql "$DATABASE_URL" -c "SELECT current_user, current_database();"'

echo ""
echo "8. Ensuring all tables exist and have correct ownership..."
sudo -u postgres psql servicedesk << 'EOF'

-- Show current table ownership
SELECT schemaname, tablename, tableowner FROM pg_tables WHERE schemaname = 'public';

-- If tables are owned by postgres, transfer them
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tableowner = 'postgres')
    LOOP
        EXECUTE 'ALTER TABLE ' || quote_ident(r.tablename) || ' OWNER TO servicedesk';
        RAISE NOTICE 'Changed owner of table % to servicedesk', r.tablename;
    END LOOP;
END
$$;

-- Show updated ownership
SELECT schemaname, tablename, tableowner FROM pg_tables WHERE schemaname = 'public';

\q
EOF

echo ""
echo "9. Testing table access after ownership fix..."
sudo -u www-data bash -c 'source .env && psql "$DATABASE_URL" -c "SELECT '\''tickets'\'' as table_name, count(*) FROM tickets UNION ALL SELECT '\''changes'\'', count(*) FROM changes UNION ALL SELECT '\''users'\'', count(*) FROM users;"'

echo ""
echo "10. Starting service with corrected configuration..."
sudo systemctl start servicedesk.service

echo ""
echo "11. Monitoring for permission errors..."
sleep 5
sudo journalctl -u servicedesk.service --no-pager -n 10 | grep -E "(permission denied|Error|Warning|warmup|HTTP server)"

echo ""
echo "=== Debug Complete ==="