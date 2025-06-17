#!/bin/bash

echo "=== Fixing Local PostgreSQL Setup ==="
echo ""

cd /var/www/servicedesk

echo "1. Checking PostgreSQL service status..."
sudo systemctl status postgresql --no-pager || echo "PostgreSQL not running"

echo ""
echo "2. Starting PostgreSQL service..."
sudo systemctl start postgresql
sudo systemctl enable postgresql

echo ""
echo "3. Checking if PostgreSQL is listening on port 5432..."
sudo netstat -tlnp | grep :5432 || echo "PostgreSQL not listening on port 5432"

echo ""
echo "4. Checking PostgreSQL configuration..."
PG_VERSION=$(sudo -u postgres psql -t -c "SELECT version();" | head -1 | sed 's/.*PostgreSQL \([0-9]\+\).*/\1/')
if [ -z "$PG_VERSION" ]; then
    PG_VERSION="14"  # Default fallback
fi

echo "PostgreSQL version: $PG_VERSION"

# Find PostgreSQL config files
PG_CONFIG_DIR="/etc/postgresql/$PG_VERSION/main"
if [ ! -d "$PG_CONFIG_DIR" ]; then
    PG_CONFIG_DIR=$(find /etc/postgresql -name "main" -type d | head -1)
fi

echo "Config directory: $PG_CONFIG_DIR"

echo ""
echo "5. Configuring PostgreSQL to accept connections..."

if [ -f "$PG_CONFIG_DIR/postgresql.conf" ]; then
    # Enable listening on all addresses
    sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" "$PG_CONFIG_DIR/postgresql.conf"
    sudo sed -i "s/listen_addresses = 'localhost'/listen_addresses = '*'/" "$PG_CONFIG_DIR/postgresql.conf"
    echo "✓ Updated listen_addresses in postgresql.conf"
else
    echo "⚠ Could not find postgresql.conf"
fi

if [ -f "$PG_CONFIG_DIR/pg_hba.conf" ]; then
    # Add authentication rule for local connections
    echo "# Added for servicedesk application" | sudo tee -a "$PG_CONFIG_DIR/pg_hba.conf"
    echo "local   all             servicedesk                             md5" | sudo tee -a "$PG_CONFIG_DIR/pg_hba.conf"
    echo "host    all             servicedesk     127.0.0.1/32            md5" | sudo tee -a "$PG_CONFIG_DIR/pg_hba.conf"
    echo "host    all             servicedesk     ::1/128                 md5" | sudo tee -a "$PG_CONFIG_DIR/pg_hba.conf"
    echo "✓ Updated pg_hba.conf authentication rules"
else
    echo "⚠ Could not find pg_hba.conf"
fi

echo ""
echo "6. Creating database and user for servicedesk..."

# Create database user and database
sudo -u postgres psql << EOF
-- Create user if not exists
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'servicedesk') THEN
        CREATE USER servicedesk WITH PASSWORD 'servicedesk_password_2024';
    END IF;
END
\$\$;

-- Create database if not exists
SELECT 'CREATE DATABASE servicedesk OWNER servicedesk'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'servicedesk')\gexec

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE servicedesk TO servicedesk;
ALTER USER servicedesk CREATEDB;

\q
EOF

echo ""
echo "7. Restarting PostgreSQL to apply configuration changes..."
sudo systemctl restart postgresql

echo ""
echo "8. Testing database connection..."
sleep 2

# Test connection
export PGPASSWORD=servicedesk_password_2024
if psql -h localhost -U servicedesk -d servicedesk -c "SELECT 1;" >/dev/null 2>&1; then
    echo "✓ Database connection successful"
else
    echo "✗ Database connection failed"
    echo "Checking PostgreSQL logs..."
    sudo tail -10 /var/log/postgresql/postgresql-*.log 2>/dev/null || echo "Could not find PostgreSQL logs"
fi

echo ""
echo "9. Updating .env file with correct DATABASE_URL..."

# Backup current .env
cp .env .env.backup

# Update DATABASE_URL
sed -i 's|DATABASE_URL=.*|DATABASE_URL=postgresql://servicedesk:servicedesk_password_2024@localhost:5432/servicedesk|' .env

echo "✓ Updated DATABASE_URL in .env file"
echo "✓ Backup saved as .env.backup"

echo ""
echo "10. Testing final database connection with new URL..."
source .env
if psql "$DATABASE_URL" -c "SELECT 1;" >/dev/null 2>&1; then
    echo "✓ Final database connection test successful"
else
    echo "✗ Final database connection test failed"
fi

echo ""
echo "=== PostgreSQL Setup Complete ==="
echo ""
echo "Next steps:"
echo "1. Run: sudo systemctl restart servicedesk.service"
echo "2. Check status: sudo systemctl status servicedesk.service"
echo "3. View logs: sudo journalctl -u servicedesk.service -f"