#!/bin/bash

echo "=== Using Replit's Built-in Database ==="
echo ""

cd /var/www/servicedesk

echo "1. Stopping current service..."
sudo systemctl stop servicedesk.service

echo "2. Checking Replit database environment variables..."
echo "DATABASE_URL from Replit environment:"
echo $DATABASE_URL

echo ""
echo "3. Creating .env with Replit's database..."
cat > .env.replit << EOF
DATABASE_URL=$DATABASE_URL
NODE_ENV=production
PORT=5000
EOF

sudo -u www-data cp .env.replit .env
rm .env.replit

echo ""
echo "4. Testing Replit database connection..."
if [ ! -z "$DATABASE_URL" ]; then
    psql "$DATABASE_URL" -c "SELECT 'Replit database connection successful' as status, current_user, current_database();"
else
    echo "No DATABASE_URL found in Replit environment"
    echo "Using local PostgreSQL with simplified permissions..."
    
    # Fallback to local with minimal configuration
    sudo -u postgres psql << 'EOF'
DROP DATABASE IF EXISTS servicedesk;
DROP USER IF EXISTS servicedesk;
CREATE USER servicedesk WITH PASSWORD 'simple_pass' SUPERUSER;
CREATE DATABASE servicedesk OWNER servicedesk;
\q
EOF
    
    echo "DATABASE_URL=postgresql://servicedesk:simple_pass@localhost:5432/servicedesk" | sudo -u www-data tee .env
fi

echo ""
echo "5. Running database migration..."
sudo -u www-data npm run db:push

echo ""
echo "6. Building application..."
sudo -u www-data npm run build
sudo -u www-data cp -r dist/* server/public/

echo ""
echo "7. Starting service..."
sudo systemctl start servicedesk.service

echo ""
echo "8. Monitoring for 10 seconds..."
sleep 10
sudo journalctl -u servicedesk.service --no-pager -n 8 | grep -E "(permission denied|Error|Warning|HTTP server|Database)" || echo "No errors detected"

echo ""
echo "=== Database Setup Complete ==="