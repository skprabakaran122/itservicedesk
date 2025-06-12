#!/bin/bash

# Database Setup Fix for Production Server
echo "Fixing PostgreSQL database setup..."

# Stop the application first
pm2 stop servicedesk 2>/dev/null || true

# Check if PostgreSQL is running
if ! systemctl is-active --quiet postgresql; then
    echo "Starting PostgreSQL service..."
    sudo systemctl start postgresql
    sudo systemctl enable postgresql
fi

# Create database and user with proper permissions
echo "Setting up database and user..."
sudo -u postgres psql << 'EOF'
-- Drop existing database and user if they exist
DROP DATABASE IF EXISTS servicedesk;
DROP USER IF EXISTS servicedesk_user;

-- Create new database and user
CREATE DATABASE servicedesk;
CREATE USER servicedesk_user WITH PASSWORD 'password123';

-- Grant all privileges
GRANT ALL PRIVILEGES ON DATABASE servicedesk TO servicedesk_user;
ALTER USER servicedesk_user CREATEDB;
ALTER USER servicedesk_user SUPERUSER;

-- Connect to the database and grant schema permissions
\c servicedesk;
GRANT ALL ON SCHEMA public TO servicedesk_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO servicedesk_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO servicedesk_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO servicedesk_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO servicedesk_user;

\q
EOF

# Test database connection
echo "Testing database connection..."
if PGPASSWORD=password123 psql -h localhost -U servicedesk_user -d servicedesk -c "SELECT 1;" > /dev/null 2>&1; then
    echo "✅ Database connection successful"
else
    echo "❌ Database connection failed"
    exit 1
fi

# Navigate to project directory
cd /home/ubuntu/servicedesk

# Update environment file with correct database URL
cat > .env << 'EOF'
NODE_ENV=production
PORT=5000
DATABASE_URL=postgresql://servicedesk_user:password123@localhost:5432/servicedesk
SENDGRID_API_KEY=SG.placeholder_configure_in_admin
EOF

# Setup database schema
echo "Setting up database schema..."
npm run db:push

# Create logs directory
mkdir -p logs

# Restart application
echo "Starting application..."
pm2 restart servicedesk || pm2 start ecosystem.config.cjs

# Save PM2 configuration
pm2 save

echo "Database setup complete!"
echo "Checking application status..."
sleep 3
pm2 logs servicedesk --lines 5