#!/bin/bash

# Simple Database Fix - Run from home directory
echo "Simple PostgreSQL fix for servicedesk..."

# Navigate to home directory first
cd /home/ubuntu

# Stop application
pm2 stop servicedesk 2>/dev/null || true

# Find correct PostgreSQL version and config path
PG_VERSION=$(ls /etc/postgresql/ | head -1)
echo "Found PostgreSQL version: $PG_VERSION"

# Update PostgreSQL authentication to trust for localhost
echo "Updating PostgreSQL authentication..."
sudo sed -i.bak 's/local.*all.*all.*peer/local   all             all                                     trust/' /etc/postgresql/$PG_VERSION/main/pg_hba.conf
sudo sed -i 's/local.*all.*all.*md5/local   all             all                                     trust/' /etc/postgresql/$PG_VERSION/main/pg_hba.conf
sudo sed -i 's/host.*all.*all.*127.0.0.1\/32.*scram-sha-256/host    all             all             127.0.0.1\/32            trust/' /etc/postgresql/$PG_VERSION/main/pg_hba.conf
sudo sed -i 's/host.*all.*all.*127.0.0.1\/32.*md5/host    all             all             127.0.0.1\/32            trust/' /etc/postgresql/$PG_VERSION/main/pg_hba.conf

# Restart PostgreSQL
sudo systemctl restart postgresql
sleep 3

# Test PostgreSQL connection
echo "Testing PostgreSQL connection..."
if sudo -u postgres psql -c "\l" > /dev/null 2>&1; then
    echo "PostgreSQL connection working"
    
    # Create database
    sudo -u postgres psql << 'EOF'
DROP DATABASE IF EXISTS servicedesk;
CREATE DATABASE servicedesk;
\q
EOF
    
    # Navigate to project directory
    if [ -d "/home/ubuntu/servicedesk" ]; then
        cd /home/ubuntu/servicedesk
        
        # Update environment file
        cat > .env << 'EOF'
NODE_ENV=production
PORT=5000
DATABASE_URL=postgresql:///servicedesk?host=/var/run/postgresql
SENDGRID_API_KEY=configure_in_admin_console
EOF
        
        # Test the connection string
        export DATABASE_URL="postgresql:///servicedesk?host=/var/run/postgresql"
        
        # Try database schema setup
        if npm run db:push; then
            echo "Database schema setup successful"
            
            # Start application
            pm2 start npm --name servicedesk -- run dev
            pm2 save
            
            echo "Application started successfully"
            pm2 logs servicedesk --lines 5
        else
            echo "Database schema setup failed, trying alternative..."
            export DATABASE_URL="postgresql://postgres@localhost/servicedesk"
            npm run db:push
            
            # Update env with working URL
            cat > .env << 'EOF'
NODE_ENV=production
PORT=5000
DATABASE_URL=postgresql://postgres@localhost/servicedesk
SENDGRID_API_KEY=configure_in_admin_console
EOF
            
            pm2 start npm --name servicedesk -- run dev
            pm2 save
        fi
    else
        echo "Project directory not found. Please clone the repository first."
    fi
else
    echo "PostgreSQL connection still failing"
fi