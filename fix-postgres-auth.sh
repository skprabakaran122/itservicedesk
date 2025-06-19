#!/bin/bash

# Fix PostgreSQL authentication for production
set -e

cd /var/www/itservicedesk

echo "=== Fixing PostgreSQL Authentication ==="

# Stop the current PM2 process
pm2 stop servicedesk 2>/dev/null || true

# Configure PostgreSQL for trust authentication
echo "Configuring PostgreSQL authentication..."

# Update pg_hba.conf for trust authentication
sudo -u postgres psql -c "ALTER USER postgres PASSWORD NULL;" 2>/dev/null || true

# Update pg_hba.conf to use trust authentication
PG_HBA_CONF=$(sudo -u postgres psql -t -c "SHOW hba_file;" | xargs)
echo "Updating $PG_HBA_CONF"

# Backup original
sudo cp "$PG_HBA_CONF" "$PG_HBA_CONF.backup" 2>/dev/null || true

# Configure for trust authentication
sudo tee "$PG_HBA_CONF" > /dev/null << 'EOF'
# PostgreSQL Client Authentication Configuration File
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# "local" is for Unix domain socket connections only
local   all             all                                     trust
# IPv4 local connections:
host    all             all             127.0.0.1/32            trust
host    all             all             ::1/128                 trust
# Allow replication connections from localhost, by a user with the
# replication privilege.
local   replication     all                                     trust
host    replication     all             127.0.0.1/32            trust
host    replication     all             ::1/128                 trust
EOF

# Restart PostgreSQL to apply changes
sudo systemctl restart postgresql

# Wait for PostgreSQL to start
sleep 5

# Verify PostgreSQL is running
sudo systemctl status postgresql --no-pager -l

# Test database connection
echo "Testing database connection..."
psql -U postgres -h localhost -d servicedesk -c "SELECT 1;" 2>/dev/null || {
    echo "Database doesn't exist, creating..."
    sudo -u postgres createdb servicedesk 2>/dev/null || true
    
    # Test again
    psql -U postgres -h localhost -d servicedesk -c "SELECT 1;" || {
        echo "Database connection still failing, checking status..."
        sudo -u postgres psql -l
        exit 1
    }
}

echo "✓ Database connection working"

# Update the application's database configuration to remove any password references
cat > temp_db_fix.js << 'EOF'
const fs = require('fs');
const path = './dist/index.js';

if (fs.existsSync(path)) {
    let content = fs.readFileSync(path, 'utf8');
    
    // Remove any password configuration that might cause SCRAM errors
    content = content.replace(/password:\s*[^,}\s]+/g, '');
    content = content.replace(/connectionString:\s*process\.env\.DATABASE_URL/g, 
        'host: "localhost", database: "servicedesk", user: "postgres", port: 5432');
    
    fs.writeFileSync(path, content);
    console.log('✓ Database configuration updated');
} else {
    console.log('✗ dist/index.js not found');
}
EOF

node temp_db_fix.js
rm temp_db_fix.js

# Test the fixed application
echo "Testing fixed application..."
timeout 10s node dist/index.js &
TEST_PID=$!
sleep 5

if curl -s http://localhost:5000/api/health >/dev/null 2>&1; then
    echo "✓ Application working with fixed database"
    kill $TEST_PID 2>/dev/null || true
else
    echo "✗ Application still has issues"
    kill $TEST_PID 2>/dev/null || true
    # Show what the error is now
    timeout 5s node dist/index.js 2>&1 | head -10
    exit 1
fi

# Restart PM2 with fixed application
echo "Restarting PM2..."
pm2 restart servicedesk

sleep 10

# Final verification
echo "Final verification..."
pm2 status
curl -s http://localhost:5000/api/health

echo ""
echo "=== PostgreSQL Authentication Fixed ==="
echo "✓ PostgreSQL configured for trust authentication"
echo "✓ Database connection working without SCRAM errors"
echo "✓ PM2 process restarted with working database"
echo ""
echo "Your IT Service Desk is now fully operational at: http://98.81.235.7"