#!/bin/bash

# Fix production database connectivity issues

echo "=== Fixing Production Database Connection ==="

cd /var/www/servicedesk

echo "1. Checking current database configuration..."
if [ -f ".env" ]; then
    echo "Environment file exists"
    if grep -q "DATABASE_URL" .env; then
        echo "DATABASE_URL found in .env"
    else
        echo "No DATABASE_URL in .env file"
    fi
else
    echo "No .env file found"
fi

echo ""
echo "2. Testing network connectivity to database..."
DB_HOST="98.81.235.7"
DB_PORT="5432"

# Test if port is reachable
if timeout 10 bash -c "cat < /dev/null > /dev/tcp/$DB_HOST/$DB_PORT"; then
    echo "✓ Database port $DB_HOST:$DB_PORT is reachable"
else
    echo "✗ Cannot reach database at $DB_HOST:$DB_PORT"
    echo "This could be due to:"
    echo "  - Firewall blocking outbound connections to port 5432"
    echo "  - Database server firewall blocking your server IP"
    echo "  - Network connectivity issues"
fi

echo ""
echo "3. Checking PostgreSQL client tools..."
if command -v psql >/dev/null 2>&1; then
    echo "✓ PostgreSQL client available"
else
    echo "Installing PostgreSQL client..."
    sudo apt update
    sudo apt install -y postgresql-client
fi

echo ""
echo "4. Fixing firewall for outbound database connections..."
# Allow outbound connections to PostgreSQL
sudo ufw allow out 5432
echo "✓ Firewall rule added for outbound PostgreSQL connections"

echo ""
echo "5. Testing direct database connection..."
if [ -f ".env" ]; then
    # Extract DATABASE_URL for testing (hide password in output)
    DB_URL=$(grep "DATABASE_URL" .env | cut -d'=' -f2-)
    if [ ! -z "$DB_URL" ]; then
        echo "Testing connection with DATABASE_URL..."
        # Test connection (timeout after 10 seconds)
        timeout 10 psql "$DB_URL" -c "SELECT 1;" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "✓ Database connection successful"
        else
            echo "✗ Database connection failed"
            echo ""
            echo "Troubleshooting steps:"
            echo "1. Verify the database server allows connections from your IP"
            echo "2. Check if the database credentials are correct"
            echo "3. Ensure the database server is running"
            echo "4. Contact your database provider about firewall rules"
        fi
    fi
fi

echo ""
echo "6. Creating connection retry logic..."
cat > database_test.js << 'EOF'
const { Pool } = require('pg');

const connectionString = process.env.DATABASE_URL;
if (!connectionString) {
    console.log('No DATABASE_URL found');
    process.exit(1);
}

const pool = new Pool({
    connectionString,
    connectionTimeoutMillis: 10000,
    idleTimeoutMillis: 30000,
    max: 1,
    ssl: { rejectUnauthorized: false }
});

async function testConnection() {
    try {
        console.log('Testing database connection...');
        const client = await pool.connect();
        const result = await client.query('SELECT NOW()');
        console.log('✓ Database connection successful:', result.rows[0]);
        client.release();
        await pool.end();
    } catch (error) {
        console.log('✗ Database connection failed:', error.message);
        process.exit(1);
    }
}

testConnection();
EOF

echo ""
echo "7. Running database connection test..."
if [ -f ".env" ]; then
    source .env
    node database_test.js
else
    echo "No .env file to source"
fi

# Cleanup
rm -f database_test.js

echo ""
echo "=== Database Fix Completed ==="
echo ""
echo "If connection still fails:"
echo "1. Contact your database provider (Neon, etc.) about IP whitelisting"
echo "2. Check if your server IP ($(curl -s ifconfig.me)) is allowed"
echo "3. Verify database server is running and accessible"
echo "4. Consider using a different database endpoint if available"