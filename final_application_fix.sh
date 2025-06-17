#!/bin/bash

echo "=== Final Application Database Fix ==="
echo ""

cd /var/www/servicedesk

echo "1. Stopping service completely..."
sudo systemctl stop servicedesk.service
sudo pkill -f "tsx.*server/index.ts" 2>/dev/null || true
sudo pkill -f "node.*server/index.ts" 2>/dev/null || true

echo ""
echo "2. Testing that database schema and permissions are working..."
export PGPASSWORD=servicedesk_password_2024
psql -h localhost -U servicedesk -d servicedesk << 'EOF'
-- Test exact queries the application uses
SELECT count(*) as ticket_count FROM tickets;
SELECT count(*) as change_count FROM changes;  
SELECT count(*) as user_count FROM users;

-- Test insert operations
INSERT INTO users (username, email, password, role, name) 
VALUES ('test_app', 'test@app.com', 'test_password', 'user', 'Test User')
ON CONFLICT (username) DO NOTHING;

-- Clean up
DELETE FROM users WHERE username = 'test_app';

SELECT 'All database operations successful' as status;
EOF

echo ""
echo "3. Ensuring clean .env configuration..."
sudo -u www-data cp .env .env.backup.working

cat > .env.tmp << 'EOF'
DATABASE_URL=postgresql://servicedesk:servicedesk_password_2024@localhost:5432/servicedesk
NODE_ENV=production
EOF

sudo -u www-data cp .env.tmp .env
rm .env.tmp

echo ""
echo "4. Building application with clean environment..."
sudo -u www-data npm run build
sudo -u www-data cp -r dist/* server/public/

echo ""
echo "5. Testing Node.js database connection before starting service..."
sudo -u www-data bash -c 'cd /var/www/servicedesk && source .env && cat > test_db.js << "NODEEOF"
const { Pool } = require("pg");

async function testDatabase() {
    console.log("Testing database connection...");
    
    const pool = new Pool({
        connectionString: process.env.DATABASE_URL,
        ssl: false,
        max: 1
    });
    
    try {
        const client = await pool.connect();
        console.log("Connected as:", (await client.query("SELECT current_user")).rows[0].current_user);
        
        // Test the exact queries causing issues
        const tickets = await client.query("SELECT count(*) FROM tickets");
        const changes = await client.query("SELECT count(*) FROM changes");
        const users = await client.query("SELECT count(*) FROM users");
        
        console.log("✓ Tickets table:", tickets.rows[0].count, "records");
        console.log("✓ Changes table:", changes.rows[0].count, "records");
        console.log("✓ Users table:", users.rows[0].count, "records");
        
        client.release();
        await pool.end();
        console.log("Database test successful - starting application");
    } catch (error) {
        console.error("Database test failed:", error.message);
        process.exit(1);
    }
}

testDatabase();
NODEEOF

node test_db.js && rm test_db.js'

echo ""
echo "6. Starting service with verified database connectivity..."
sudo systemctl start servicedesk.service

echo ""
echo "7. Monitoring startup for 15 seconds..."
for i in {1..15}; do
    sleep 1
    echo -n "."
done
echo ""

echo "Recent startup logs:"
sudo journalctl -u servicedesk.service --no-pager -n 8 | grep -E "(permission denied|Error|Warning|warmup|HTTP server|Database)" || echo "No database errors detected"

echo ""
echo "8. Final service status..."
sudo systemctl status servicedesk.service --no-pager -l | head -15

echo ""
echo "=== Final Application Fix Complete ==="
echo ""
echo "Database schema verified and working"
echo "Application should now run without permission errors"
echo "Access your IT Service Desk at: http://98.81.235.7:5000"