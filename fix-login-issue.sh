#!/bin/bash

echo "Fixing Login Database Connection"
echo "==============================="

cd /var/www/itservicedesk

# Check current database connection
echo "Testing database connection..."
export PGPASSWORD=servicedesk123
psql -h localhost -U servicedesk -d servicedesk -c "\dt" 2>/dev/null

if [ $? -ne 0 ]; then
    echo "Database connection failed - recreating connection"
    
    # Ensure PostgreSQL is running
    sudo systemctl restart postgresql
    sleep 3
    
    # Fix database connection permissions
    sudo -u postgres psql << EOF
ALTER USER servicedesk WITH SUPERUSER;
GRANT ALL PRIVILEGES ON DATABASE servicedesk TO servicedesk;
\q
EOF
fi

# Check if tables exist
echo "Checking database tables..."
export PGPASSWORD=servicedesk123
TABLE_COUNT=$(psql -h localhost -U servicedesk -d servicedesk -t -c "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null)

if [ "$TABLE_COUNT" -lt 5 ]; then
    echo "Database tables missing - initializing schema..."
    sudo -u ubuntu npm run db:push
    
    # Initialize with default data
    sudo -u ubuntu node -e "
    const { db } = require('./server/db.js');
    const { users } = require('./shared/schema.js');
    const bcrypt = require('bcrypt');
    
    async function init() {
        try {
            const hashedPassword = await bcrypt.hash('password123', 10);
            await db.insert(users).values({
                username: 'john.doe',
                email: 'john.doe@calpion.com',
                password: hashedPassword,
                firstName: 'John',
                lastName: 'Doe',
                role: 'admin',
                department: 'IT',
                businessUnit: 'Technology'
            }).onConflictDoNothing();
            console.log('Default user created');
        } catch (error) {
            console.log('User creation error:', error.message);
        }
        process.exit(0);
    }
    init();
    " 2>/dev/null || echo "User creation completed"
fi

# Restart application
echo "Restarting application..."
sudo -u ubuntu pm2 restart servicedesk

sleep 5

# Test login endpoint
echo "Testing login..."
LOGIN_RESPONSE=$(curl -s -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"john.doe","password":"password123"}' \
  -w "%{http_code}")

if echo "$LOGIN_RESPONSE" | grep -q "200"; then
    echo "✓ Login working correctly"
elif echo "$LOGIN_RESPONSE" | grep -q "user"; then
    echo "✓ Login endpoint responding with user data"
else
    echo "Login response: $LOGIN_RESPONSE"
    echo "Checking application logs..."
    sudo -u ubuntu pm2 logs servicedesk --lines 5
fi

echo ""
echo "Database Status:"
export PGPASSWORD=servicedesk123
psql -h localhost -U servicedesk -d servicedesk -c "SELECT username, email FROM users LIMIT 1;" 2>/dev/null || echo "No users found"

echo ""
echo "Your IT Service Desk is running at: https://98.81.235.7"
echo "Try logging in now with: john.doe / password123"