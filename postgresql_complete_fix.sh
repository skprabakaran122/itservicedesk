#!/bin/bash

# Complete PostgreSQL Fix for Authentication Issues
echo "Fixing PostgreSQL authentication issues..."

# Stop application
pm2 stop servicedesk 2>/dev/null || true

# Check PostgreSQL version and status
echo "PostgreSQL status:"
sudo systemctl status postgresql --no-pager
echo "PostgreSQL version:"
sudo -u postgres psql -c "SELECT version();"

# Reset PostgreSQL authentication
echo "Resetting PostgreSQL configuration..."

# Check current users and databases
echo "Current databases:"
sudo -u postgres psql -l

echo "Current users:"
sudo -u postgres psql -c "\du"

# Complete cleanup and recreation
sudo -u postgres psql << 'EOF'
-- Terminate all connections to the database
SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'servicedesk';

-- Drop everything cleanly
DROP DATABASE IF EXISTS servicedesk;
DROP USER IF EXISTS servicedesk_user;

-- Create user first
CREATE USER servicedesk_user WITH PASSWORD 'password123';

-- Create database owned by the user
CREATE DATABASE servicedesk OWNER servicedesk_user;

-- Grant all necessary privileges
ALTER USER servicedesk_user CREATEDB;
ALTER USER servicedesk_user SUPERUSER;
GRANT ALL PRIVILEGES ON DATABASE servicedesk TO servicedesk_user;

-- Connect to database and set schema permissions
\c servicedesk;
GRANT ALL ON SCHEMA public TO servicedesk_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO servicedesk_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO servicedesk_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO servicedesk_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO servicedesk_user;

\q
EOF

# Test connection with explicit parameters
echo "Testing database connection..."
export PGPASSWORD=password123
if psql -h localhost -p 5432 -U servicedesk_user -d servicedesk -c "SELECT 'Connection successful' as status;"; then
    echo "✅ Database connection working"
else
    echo "❌ Database connection still failing"
    
    # Check pg_hba.conf for authentication method
    echo "Checking PostgreSQL authentication configuration..."
    sudo cat /etc/postgresql/*/main/pg_hba.conf | grep -v "^#" | grep -v "^$"
    
    # Try to fix pg_hba.conf if needed
    echo "Updating pg_hba.conf for local connections..."
    sudo sed -i 's/local   all             all                                     peer/local   all             all                                     md5/' /etc/postgresql/*/main/pg_hba.conf
    
    # Restart PostgreSQL
    sudo systemctl restart postgresql
    sleep 5
    
    # Test again
    if psql -h localhost -p 5432 -U servicedesk_user -d servicedesk -c "SELECT 'Connection successful' as status;"; then
        echo "✅ Database connection working after pg_hba.conf fix"
    else
        echo "❌ Still having connection issues"
        exit 1
    fi
fi

# Navigate to project and update environment
cd /home/ubuntu/servicedesk

# Create correct environment file
cat > .env << 'EOF'
NODE_ENV=production
PORT=5000
DATABASE_URL=postgresql://servicedesk_user:password123@localhost:5432/servicedesk
SENDGRID_API_KEY=SG.placeholder_configure_in_admin
EOF

# Update drizzle config to use environment variable
export DATABASE_URL="postgresql://servicedesk_user:password123@localhost:5432/servicedesk"

# Setup database schema
echo "Setting up database schema..."
npm run db:push

if [ $? -eq 0 ]; then
    echo "✅ Database schema created successfully"
else
    echo "❌ Database schema creation failed"
    exit 1
fi

# Restart application
echo "Starting application..."
pm2 restart servicedesk || pm2 start ecosystem.config.cjs

# Save PM2 config
pm2 save

echo "Setup complete! Checking application..."
sleep 3
pm2 logs servicedesk --lines 10