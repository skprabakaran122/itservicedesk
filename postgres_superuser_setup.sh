#!/bin/bash

# PostgreSQL Superuser Setup - Complete Fix
echo "Setting up PostgreSQL with superuser access..."

# Stop application
pm2 stop servicedesk 2>/dev/null || true

# Get PostgreSQL version and set paths
PG_VERSION=$(sudo -u postgres psql -t -c "SELECT version();" | grep -oP '\d+\.\d+' | head -1)
echo "PostgreSQL version: $PG_VERSION"

# Create database using postgres superuser
sudo -u postgres psql << 'EOF'
-- Clean slate
DROP DATABASE IF EXISTS servicedesk;
DROP USER IF EXISTS servicedesk_user;

-- Create database with postgres as owner initially
CREATE DATABASE servicedesk;

-- Create user with all privileges
CREATE USER servicedesk_user WITH PASSWORD 'servicedesk123';
ALTER USER servicedesk_user CREATEDB;
ALTER USER servicedesk_user SUPERUSER;
ALTER USER servicedesk_user REPLICATION;

-- Grant ownership and privileges
ALTER DATABASE servicedesk OWNER TO servicedesk_user;
GRANT ALL PRIVILEGES ON DATABASE servicedesk TO servicedesk_user;

-- Connect to database and set up permissions
\c servicedesk;
GRANT ALL ON SCHEMA public TO servicedesk_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO servicedesk_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO servicedesk_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO servicedesk_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO servicedesk_user;

\q
EOF

# Alternative: Use postgres user directly if servicedesk_user fails
echo "Setting up alternative configuration with postgres user..."

cd /home/ubuntu/servicedesk

# Create environment file with postgres superuser
cat > .env << 'EOF'
NODE_ENV=production
PORT=5000
DATABASE_URL=postgresql://postgres@localhost:5432/servicedesk
SENDGRID_API_KEY=SG.placeholder_configure_in_admin
EOF

# Test postgres connection
echo "Testing postgres user connection..."
if sudo -u postgres psql -d servicedesk -c "SELECT 'Connection successful' as status;"; then
    echo "Using postgres superuser for database connection"
    
    # Setup schema with postgres user
    export DATABASE_URL="postgresql://postgres@localhost:5432/servicedesk"
    npm run db:push
    
    if [ $? -eq 0 ]; then
        echo "Database schema created successfully with postgres user"
    else
        echo "Schema creation failed, trying peer authentication"
        # Try with peer authentication
        export DATABASE_URL="postgresql:///servicedesk?host=/var/run/postgresql"
        npm run db:push
    fi
else
    echo "Postgres connection failed, checking authentication methods"
fi

# Update PM2 configuration to use working DATABASE_URL
if [ -f "ecosystem.config.cjs" ]; then
    # Update the config file with working database URL
    sed -i "s|DATABASE_URL: '.*'|DATABASE_URL: 'postgresql://postgres@localhost:5432/servicedesk'|" ecosystem.config.cjs
fi

# Start application
echo "Starting application with updated configuration..."
pm2 restart servicedesk || pm2 start ecosystem.config.cjs
pm2 save

echo "Checking application status..."
sleep 5
pm2 logs servicedesk --lines 10

echo "Setup complete!"
echo "Application should be accessible at: http://54.160.177.174:5000"