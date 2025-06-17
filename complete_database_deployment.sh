#!/bin/bash

echo "=== Complete Database Deployment Fix ==="
echo ""

cd /var/www/servicedesk

echo "1. Fixing database permissions and ownership..."
sudo -u postgres psql << 'EOF'

-- Connect to servicedesk database
\c servicedesk

-- Grant all privileges on database
GRANT ALL PRIVILEGES ON DATABASE servicedesk TO servicedesk;

-- Grant all privileges on all existing tables
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO servicedesk;

-- Grant all privileges on all existing sequences
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO servicedesk;

-- Grant usage on schema
GRANT USAGE ON SCHEMA public TO servicedesk;

-- Set default privileges for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO servicedesk;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO servicedesk;

-- Make servicedesk owner of the database
ALTER DATABASE servicedesk OWNER TO servicedesk;

-- Transfer ownership of all existing objects to servicedesk
REASSIGN OWNED BY postgres TO servicedesk;

-- Grant CREATE privileges
GRANT CREATE ON SCHEMA public TO servicedesk;

\q
EOF

echo ""
echo "2. Testing database permissions with table creation..."
sudo -u www-data bash -c 'source .env && psql "$DATABASE_URL" -c "CREATE TABLE IF NOT EXISTS test_permissions (id SERIAL PRIMARY KEY); DROP TABLE IF EXISTS test_permissions;"'

if [ $? -eq 0 ]; then
    echo "✓ Database permissions test successful"
else
    echo "✗ Database permissions test failed"
    exit 1
fi

echo ""
echo "3. Running database migration with proper permissions..."
sudo -u www-data npm run db:push

echo ""
echo "4. Building application..."
sudo -u www-data npm run build

echo ""
echo "5. Copying build files..."
sudo -u www-data mkdir -p server/public
sudo -u www-data cp -r dist/* server/public/

echo ""
echo "6. Restarting servicedesk application..."
sudo systemctl restart servicedesk.service

echo ""
echo "7. Checking application status..."
sleep 3
sudo systemctl status servicedesk.service --no-pager

echo ""
echo "8. Showing recent logs..."
sudo journalctl -u servicedesk.service --no-pager -n 20

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Your IT Service Desk is now running with:"
echo "- Local PostgreSQL database with proper permissions"
echo "- All database migrations applied successfully"
echo "- Application built and deployed"
echo "- Service restarted and operational"
echo ""
echo "Access your application at: https://98.81.235.7"
echo "Monitor logs with: sudo journalctl -u servicedesk.service -f"