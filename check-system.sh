#!/bin/bash

echo "System Status Check"
echo "==================="

echo "Checking installed packages and services..."
echo ""

# Check Node.js
echo "Node.js:"
if command -v node >/dev/null 2>&1; then
    echo "  ✓ Installed: $(node --version)"
    echo "  Location: $(which node)"
else
    echo "  ✗ Not installed"
fi

# Check npm
echo "npm:"
if command -v npm >/dev/null 2>&1; then
    echo "  ✓ Installed: $(npm --version)"
    echo "  Location: $(which npm)"
else
    echo "  ✗ Not installed"
fi

# Check PM2
echo "PM2:"
if command -v pm2 >/dev/null 2>&1; then
    echo "  ✓ Installed: $(pm2 --version)"
    echo "  Status: $(pm2 list | grep -c 'online' || echo '0') processes running"
else
    echo "  ✗ Not installed"
fi

# Check PostgreSQL
echo "PostgreSQL:"
if command -v psql >/dev/null 2>&1; then
    echo "  ✓ Installed: $(psql --version)"
    echo "  Service: $(systemctl is-active postgresql || echo 'inactive')"
    echo "  Databases:"
    sudo -u postgres psql -l 2>/dev/null | grep servicedesk || echo "    No servicedesk database found"
else
    echo "  ✗ Not installed"
fi

# Check Nginx
echo "Nginx:"
if command -v nginx >/dev/null 2>&1; then
    echo "  ✓ Installed: $(nginx -v 2>&1)"
    echo "  Service: $(systemctl is-active nginx || echo 'inactive')"
    echo "  Sites enabled:"
    ls -la /etc/nginx/sites-enabled/ 2>/dev/null | grep servicedesk || echo "    No servicedesk site found"
else
    echo "  ✗ Not installed"
fi

# Check SSL certificates
echo "SSL Certificates:"
if [ -f /etc/nginx/ssl/servicedesk.crt ]; then
    echo "  ✓ Certificate exists"
    echo "  Expires: $(openssl x509 -in /etc/nginx/ssl/servicedesk.crt -noout -dates | grep notAfter)"
else
    echo "  ✗ No SSL certificate found"
fi

# Check firewall
echo "Firewall (UFW):"
echo "  Status: $(sudo ufw status | head -1)"

# Check running processes
echo ""
echo "Running processes:"
echo "Node.js processes:"
ps aux | grep node | grep -v grep || echo "  None"

echo ""
echo "Network ports in use:"
sudo netstat -tlnp 2>/dev/null | grep -E ':(80|443|3000|5432)' || echo "  None on common ports"

echo ""
echo "Disk usage in current directory:"
du -sh . 2>/dev/null || echo "  Unable to check"

echo ""
echo "Available disk space:"
df -h . | tail -1

echo ""
echo "==================="
echo "System check complete"