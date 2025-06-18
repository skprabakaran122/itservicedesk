#!/bin/bash

echo "Checking Deployment Status"
echo "=========================="

# Check if services are running
echo "Service Status:"
echo "---------------"
echo "Node.js: $(command -v node && node --version || echo 'Not installed')"
echo "npm: $(command -v npm && npm --version || echo 'Not installed')"
echo "PM2: $(command -v pm2 && pm2 --version || echo 'Not installed')"
echo "PostgreSQL: $(systemctl is-active postgresql || echo 'Not running')"
echo "Nginx: $(systemctl is-active nginx || echo 'Not running')"

echo ""
echo "Running Processes:"
echo "------------------"
ps aux | grep -E "(node|nginx|postgres)" | grep -v grep || echo "No relevant processes found"

echo ""
echo "Port Status:"
echo "------------"
sudo netstat -tlnp | grep -E ":(80|443|3000|5432)" || echo "No services on expected ports"

echo ""
echo "PM2 Status:"
echo "-----------"
if command -v pm2 >/dev/null 2>&1; then
    pm2 list
else
    echo "PM2 not installed"
fi

echo ""
echo "Recent Logs:"
echo "------------"
if [ -f deployment-*.log ]; then
    echo "Found deployment log:"
    ls -la deployment-*.log
    echo ""
    echo "Last 20 lines:"
    tail -20 deployment-*.log
elif [ -d logs ]; then
    echo "Application logs:"
    ls -la logs/
    if [ -f logs/combined.log ]; then
        tail -10 logs/combined.log
    fi
else
    echo "No logs found"
fi

echo ""
echo "Nginx Status:"
echo "-------------"
if [ -f /etc/nginx/sites-enabled/servicedesk ]; then
    echo "✓ Nginx site configured"
    sudo nginx -t
else
    echo "✗ Nginx not configured"
fi

echo ""
echo "SSL Certificate:"
echo "----------------"
if [ -f /etc/nginx/ssl/servicedesk.crt ]; then
    echo "✓ SSL certificate exists"
    openssl x509 -in /etc/nginx/ssl/servicedesk.crt -noout -dates
else
    echo "✗ No SSL certificate"
fi