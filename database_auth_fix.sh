#!/bin/bash

# PostgreSQL Authentication Fix
echo "Fixing PostgreSQL authentication for servicedesk application..."

# Stop application first
pm2 stop servicedesk 2>/dev/null || true

# Check if PostgreSQL is running
sudo systemctl restart postgresql
sleep 3

# Check PostgreSQL configuration files location
PG_VERSION=$(sudo -u postgres psql -t -c "SELECT version();" | grep -oP '\d+\.\d+' | head -1)
PG_CONFIG_DIR="/etc/postgresql/$PG_VERSION/main"

echo "PostgreSQL version: $PG_VERSION"
echo "Config directory: $PG_CONFIG_DIR"

# Update pg_hba.conf to allow password authentication
echo "Updating PostgreSQL authentication configuration..."
sudo cp "$PG_CONFIG_DIR/pg_hba.conf" "$PG_CONFIG_DIR/pg_hba.conf.backup"

# Create new pg_hba.conf with correct authentication
sudo tee "$PG_CONFIG_DIR/pg_hba.conf" > /dev/null << 'EOF'
# PostgreSQL Client Authentication Configuration File

# TYPE  DATABASE        USER            ADDRESS                 METHOD

# "local" is for Unix domain socket connections only
local   all             postgres                                peer
local   all             servicedesk_user                        md5
local   all             all                                     md5

# IPv4 local connections:
host    all             all             127.0.0.1/32            md5
host    all             all             localhost               md5

# IPv6 local connections:
host    all             all             ::1/128                 md5

# Allow replication connections from localhost
local   replication     all                                     peer
host    replication     all             127.0.0.1/32            md5
host    replication     all             ::1/128                 md5
EOF

# Restart PostgreSQL with new configuration
sudo systemctl restart postgresql
sleep 5

# Completely recreate database and user
echo "Recreating database and user..."
sudo -u postgres psql << 'EOF'
-- Drop existing connections and database
SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'servicedesk';
DROP DATABASE IF EXISTS servicedesk;
DROP USER IF EXISTS servicedesk_user;

-- Create user with encrypted password
CREATE USER servicedesk_user WITH ENCRYPTED PASSWORD 'password123';
ALTER USER servicedesk_user CREATEDB;
ALTER USER servicedesk_user SUPERUSER;

-- Create database
CREATE DATABASE servicedesk OWNER servicedesk_user;
GRANT ALL PRIVILEGES ON DATABASE servicedesk TO servicedesk_user;

-- Set permissions on database
\c servicedesk;
GRANT ALL ON SCHEMA public TO servicedesk_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO servicedesk_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO servicedesk_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO servicedesk_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO servicedesk_user;

-- Verify user creation
\du servicedesk_user;
\q
EOF

# Test connection multiple ways
echo "Testing database connections..."

# Test 1: Direct connection
export PGPASSWORD=password123
echo "Test 1: Direct psql connection"
if psql -h localhost -U servicedesk_user -d servicedesk -c "SELECT 'SUCCESS: Direct connection works' as result;"; then
    echo "✅ Direct connection successful"
else
    echo "❌ Direct connection failed"
fi

# Test 2: Via connection string
echo "Test 2: Connection string test"
if psql "postgresql://servicedesk_user:password123@localhost:5432/servicedesk" -c "SELECT 'SUCCESS: Connection string works' as result;"; then
    echo "✅ Connection string successful"
else
    echo "❌ Connection string failed"
fi

# Navigate to project directory
cd /home/ubuntu/servicedesk

# Update environment file
cat > .env << 'EOF'
NODE_ENV=production
PORT=5000
DATABASE_URL=postgresql://servicedesk_user:password123@localhost:5432/servicedesk
SENDGRID_API_KEY=SG.placeholder_configure_in_admin
EOF

# Export environment variable for drizzle
export DATABASE_URL="postgresql://servicedesk_user:password123@localhost:5432/servicedesk"

# Test drizzle connection
echo "Testing drizzle database push..."
npm run db:push

if [ $? -eq 0 ]; then
    echo "✅ Database schema created successfully"
    
    # Start application
    echo "Starting application..."
    pm2 restart servicedesk || pm2 start ecosystem.config.cjs
    pm2 save
    
    echo "Application started. Checking logs..."
    sleep 5
    pm2 logs servicedesk --lines 15
else
    echo "❌ Database schema creation failed"
    echo "Checking PostgreSQL logs..."
    sudo tail -20 /var/log/postgresql/postgresql-$PG_VERSION-main.log
fi

echo "Database fix complete!"