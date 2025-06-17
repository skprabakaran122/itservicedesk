#!/bin/bash

echo "=== Complete PostgreSQL Fix ==="
echo ""

cd /var/www/servicedesk

echo "1. Installing net-tools for network diagnostics..."
sudo apt update && sudo apt install -y net-tools

echo ""
echo "2. Starting PostgreSQL cluster properly..."
sudo -u postgres pg_ctlcluster 14 main start

echo ""
echo "3. Checking PostgreSQL is listening..."
sudo netstat -tlnp | grep :5432

echo ""
echo "4. Fixing .env file permissions..."
sudo chown www-data:www-data .env
sudo chmod 644 .env

echo ""
echo "5. Updating DATABASE_URL..."
sudo -u www-data cp .env .env.backup.$(date +%Y%m%d_%H%M%S)
sudo -u www-data sed -i 's|DATABASE_URL=.*|DATABASE_URL=postgresql://servicedesk:servicedesk_password_2024@localhost:5432/servicedesk|' .env

echo ""
echo "6. Testing database connection..."
sudo -u www-data bash -c 'source .env && psql "$DATABASE_URL" -c "SELECT 1;"'

echo ""
echo "7. Running database migrations..."
sudo -u www-data npm run db:push

echo ""
echo "8. Building application..."
sudo -u www-data npm run build

echo ""
echo "9. Copying build files..."
sudo -u www-data cp -r dist/* server/public/

echo ""
echo "10. Restarting servicedesk application..."
sudo systemctl restart servicedesk.service

echo ""
echo "11. Checking application status..."
sudo systemctl status servicedesk.service --no-pager

echo ""
echo "=== Complete Fix Finished ==="
echo ""
echo "Your application should now be running with local PostgreSQL database."
echo "Check logs with: sudo journalctl -u servicedesk.service -f"