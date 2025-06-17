#!/bin/bash

echo "=== Restart with Fresh Database Connections ==="
echo ""

cd /var/www/servicedesk

echo "1. Stopping service completely..."
sudo systemctl stop servicedesk.service

echo ""
echo "2. Killing any remaining Node.js processes..."
sudo pkill -f "tsx.*server/index.ts" || echo "No remaining processes"
sudo pkill -f "servicedesk" || echo "No servicedesk processes"

echo ""
echo "3. Clearing any PostgreSQL connection cache..."
sudo systemctl restart postgresql

echo ""
echo "4. Waiting for PostgreSQL to fully restart..."
sleep 3

echo ""
echo "5. Testing fresh database connection..."
export PGPASSWORD=servicedesk_password_2024
psql -h localhost -U servicedesk -d servicedesk -c "SELECT 'Fresh connection test' as status, current_user, current_database();"

echo ""
echo "6. Verifying table permissions are still correct..."
export PGPASSWORD=servicedesk_password_2024
psql -h localhost -U servicedesk -d servicedesk -c "SELECT 'tickets' as table_name, count(*) FROM tickets UNION ALL SELECT 'changes', count(*) FROM changes UNION ALL SELECT 'users', count(*) FROM users;"

echo ""
echo "7. Starting fresh Node.js process..."
sudo systemctl start servicedesk.service

echo ""
echo "8. Monitoring startup with fresh connections..."
sleep 8
sudo journalctl -u servicedesk.service --no-pager -n 15 | grep -E "(Warning|Error|permission denied|warmup|HTTP server|SLA|AUTO-CLOSE|OVERDUE)" || echo "No errors found"

echo ""
echo "9. Final status check..."
sudo systemctl status servicedesk.service --no-pager -l

echo ""
echo "=== Fresh Connection Restart Complete ==="
echo ""
echo "Application restarted with fresh database connection pool"
echo "Permission errors should now be resolved"