#!/bin/bash

echo "=== Database URL Configuration Fix ==="
echo ""

cd /var/www/servicedesk

echo "Current server IP: $(curl -s ifconfig.me)"
echo "Database URL points to: 98.81.235.7 (same as server IP - this is the problem)"
echo ""

echo "Your DATABASE_URL is pointing to your own server instead of an external database."
echo "This needs to be corrected to point to your actual database provider."
echo ""

echo "Checking current DATABASE_URL format..."
if [ -f ".env" ]; then
    echo "Current DATABASE_URL format:"
    grep "DATABASE_URL" .env | sed 's/password=[^@]*/password=****/g'
    echo ""
    
    echo "The DATABASE_URL should point to your external database provider like:"
    echo "- Neon: DATABASE_URL=postgresql://user:pass@ep-xxx-xxx.us-east-1.aws.neon.tech:5432/dbname"
    echo "- AWS RDS: DATABASE_URL=postgresql://user:pass@database.us-east-1.rds.amazonaws.com:5432/dbname"
    echo "- DigitalOcean: DATABASE_URL=postgresql://user:pass@db-xxx.db.ondigitalocean.com:25060/dbname"
    echo ""
    
    echo "ACTION REQUIRED:"
    echo "1. Check your database provider dashboard for the correct connection string"
    echo "2. Update the DATABASE_URL in /var/www/servicedesk/.env"
    echo "3. Ensure your server IP (34.168.64.147) is whitelisted in database provider"
    echo "4. Restart the service: sudo systemctl restart servicedesk.service"
else
    echo "No .env file found"
fi

echo ""
echo "=== Fix Complete ==="