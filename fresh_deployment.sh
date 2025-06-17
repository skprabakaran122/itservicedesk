#!/bin/bash

echo "=== Fresh IT Service Desk Deployment ==="
echo ""

cd /var/www/servicedesk

echo "1. Stopping and cleaning existing service..."
sudo systemctl stop servicedesk.service 2>/dev/null || true
sudo pkill -f "tsx.*server/index.ts" 2>/dev/null || true
sudo pkill -f "node.*server/index.ts" 2>/dev/null || true

echo ""
echo "2. Creating fresh PostgreSQL database..."
sudo -u postgres psql << 'EOF'

-- Drop existing database and user completely
DROP DATABASE IF EXISTS servicedesk;
DROP USER IF EXISTS servicedesk;

-- Create fresh user with appropriate privileges
CREATE USER servicedesk WITH PASSWORD 'servicedesk_password_2024' CREATEDB;

-- Create fresh database
CREATE DATABASE servicedesk OWNER servicedesk;

-- Grant all necessary privileges
GRANT ALL PRIVILEGES ON DATABASE servicedesk TO servicedesk;

\q
EOF

echo ""
echo "3. Updating database configuration..."
sudo -u postgres psql servicedesk << 'EOF'

-- Make servicedesk owner of schema
ALTER SCHEMA public OWNER TO servicedesk;

-- Set default privileges for future objects
ALTER DEFAULT PRIVILEGES FOR ROLE servicedesk IN SCHEMA public GRANT ALL ON TABLES TO servicedesk;
ALTER DEFAULT PRIVILEGES FOR ROLE servicedesk IN SCHEMA public GRANT ALL ON SEQUENCES TO servicedesk;

\q
EOF

echo ""
echo "4. Creating clean environment configuration..."
cat > .env.fresh << 'EOF'
DATABASE_URL=postgresql://servicedesk:servicedesk_password_2024@localhost:5432/servicedesk
NODE_ENV=production
PORT=5000
EOF

sudo -u www-data cp .env.fresh .env
rm .env.fresh

echo ""
echo "5. Testing database connection..."
export PGPASSWORD=servicedesk_password_2024
psql -h localhost -U servicedesk -d servicedesk -c "SELECT 'Fresh database connection successful' as status, current_user, current_database();"

echo ""
echo "6. Installing dependencies..."
sudo -u www-data npm install

echo ""
echo "7. Running database migration..."
sudo -u www-data npm run db:push

echo ""
echo "8. Verifying database schema..."
export PGPASSWORD=servicedesk_password_2024
psql -h localhost -U servicedesk -d servicedesk -c "SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;"

echo ""
echo "9. Building application..."
sudo -u www-data npm run build

echo ""
echo "10. Deploying static files..."
sudo -u www-data mkdir -p server/public
sudo -u www-data cp -r dist/* server/public/

echo ""
echo "11. Starting fresh service..."
sudo systemctl start servicedesk.service

echo ""
echo "12. Checking service status..."
sleep 5
sudo systemctl status servicedesk.service --no-pager

echo ""
echo "13. Monitoring startup logs..."
sudo journalctl -u servicedesk.service --no-pager -n 15

echo ""
echo "=== Fresh Deployment Complete ==="
echo ""
echo "Your IT Service Desk is now running at:"
echo "http://98.81.235.7:5000"
echo ""
echo "Database: Fresh PostgreSQL with proper schema"
echo "Application: Built and deployed with clean configuration"
echo "Service: Started and operational"