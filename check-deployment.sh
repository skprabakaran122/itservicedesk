#!/bin/bash

echo "Check Ubuntu Server Deployment Issues"
echo "==================================="

cat << 'EOF'
# Comprehensive diagnosis for Ubuntu server:

cd /var/www/itservicedesk

# Check PM2 process details
echo "=== PM2 STATUS ==="
pm2 status
pm2 info servicedesk 2>/dev/null || echo "No servicedesk process info"

# Check detailed PM2 logs
echo ""
echo "=== PM2 LOGS ==="
pm2 logs servicedesk --lines 20 2>/dev/null || echo "No servicedesk logs"

# Check if the built file exists and is valid
echo ""
echo "=== BUILD VERIFICATION ==="
ls -la dist/
file dist/index.js 2>/dev/null || echo "dist/index.js not found"

# Check node process manually
echo ""
echo "=== MANUAL NODE TEST ==="
echo "Testing node execution directly..."
cd /var/www/itservicedesk
NODE_ENV=production PORT=5000 node dist/index.js &
NODE_PID=$!
sleep 10

# Check if port is bound
echo "Port check after manual start:"
ss -tlnp | grep :5000 || echo "Port 5000 not bound"

# Kill manual test
kill $NODE_PID 2>/dev/null || true

# Check database connectivity
echo ""
echo "=== DATABASE TEST ==="
sudo -u postgres psql -d servicedesk -c "SELECT 1;" 2>/dev/null || echo "Database connection failed"

# Check for conflicting processes
echo ""
echo "=== PROCESS CHECK ==="
ps aux | grep -E "(node|pm2)" | grep -v grep

# Check system resources
echo ""
echo "=== SYSTEM RESOURCES ==="
free -h
df -h /var/www/itservicedesk

# Check if there are any permission issues
echo ""
echo "=== PERMISSIONS ==="
ls -la /var/www/itservicedesk/
whoami
id

EOF