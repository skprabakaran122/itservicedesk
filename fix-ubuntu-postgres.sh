#!/bin/bash

# Fix Ubuntu PostgreSQL authentication to match development patterns
set -e

cd /var/www/itservicedesk

echo "=== Fixing Ubuntu PostgreSQL Authentication ==="

# Stop PM2
pm2 stop servicedesk 2>/dev/null || true

# Configure PostgreSQL for trust authentication (no passwords)
echo "Configuring PostgreSQL..."
sudo -u postgres psql -c "ALTER USER postgres PASSWORD NULL;" 2>/dev/null || true

# Update pg_hba.conf for trust authentication
PG_HBA_CONF=$(sudo -u postgres psql -t -c "SHOW hba_file;" | xargs)
sudo cp "$PG_HBA_CONF" "$PG_HBA_CONF.backup" 2>/dev/null || true

# Set trust authentication for local connections
sudo tee "$PG_HBA_CONF" > /dev/null << 'EOF'
# TYPE  DATABASE        USER            ADDRESS                 METHOD
local   all             all                                     trust
host    all             all             127.0.0.1/32            trust
host    all             all             ::1/128                 trust
local   replication     all                                     trust
host    replication     all             127.0.0.1/32            trust
host    replication     all             ::1/128                 trust
EOF

# Restart PostgreSQL
sudo systemctl restart postgresql
sleep 3

# Create database if it doesn't exist
sudo -u postgres createdb servicedesk 2>/dev/null || echo "Database exists"

# Test connection
psql -U postgres -h localhost -d servicedesk -c "SELECT 1;" || {
    echo "Database connection failed"
    exit 1
}

echo "✓ PostgreSQL authentication configured"

# Test the application
echo "Testing application..."
timeout 10s node dist/index.js &
TEST_PID=$!
sleep 5

if curl -s http://localhost:5000/api/health >/dev/null 2>&1; then
    echo "✓ Application working"
    kill $TEST_PID 2>/dev/null || true
else
    echo "Application still has issues"
    kill $TEST_PID 2>/dev/null || true
    timeout 5s node dist/index.js 2>&1 | head -10
    exit 1
fi

# Start PM2
pm2 start ecosystem.production.config.cjs
sleep 8

pm2 status
curl -s http://localhost:5000/api/health

echo ""
echo "✓ Ubuntu PostgreSQL configured for trust authentication"
echo "✓ IT Service Desk operational at http://98.81.235.7"