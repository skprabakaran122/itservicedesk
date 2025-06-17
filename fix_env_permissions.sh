#!/bin/bash

echo "=== Fixing .env file permissions and DATABASE_URL ==="
echo ""

cd /var/www/servicedesk

echo "1. Checking current .env file ownership and permissions..."
ls -la .env

echo ""
echo "2. Fixing ownership and permissions..."
sudo chown www-data:www-data .env
sudo chmod 644 .env

echo ""
echo "3. Creating backup and updating DATABASE_URL..."
sudo -u www-data cp .env .env.backup.$(date +%Y%m%d_%H%M%S)

# Update DATABASE_URL with proper ownership
sudo -u www-data sed -i 's|DATABASE_URL=.*|DATABASE_URL=postgresql://servicedesk:servicedesk_password_2024@localhost:5432/servicedesk|' .env

echo "✓ Updated DATABASE_URL in .env file"

echo ""
echo "4. Verifying .env file contents..."
echo "DATABASE_URL line:"
grep "DATABASE_URL" .env | sed 's/password=[^@]*/password=****/g'

echo ""
echo "5. Testing database connection with updated URL..."
sudo -u www-data bash -c 'source .env && psql "$DATABASE_URL" -c "SELECT 1;"' 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✓ Database connection successful"
else
    echo "✗ Database connection failed, checking PostgreSQL status..."
    sudo systemctl status postgresql --no-pager -l
    
    echo ""
    echo "Checking if PostgreSQL is actually running..."
    sudo ss -tlnp | grep :5432 || echo "PostgreSQL not listening on port 5432"
    
    echo ""
    echo "Starting PostgreSQL cluster..."
    sudo -u postgres pg_ctlcluster 14 main start || echo "Failed to start PostgreSQL cluster"
    
    echo ""
    echo "Testing connection again..."
    sleep 2
    sudo -u www-data bash -c 'source .env && psql "$DATABASE_URL" -c "SELECT 1;"'
fi

echo ""
echo "=== Fix Complete ==="