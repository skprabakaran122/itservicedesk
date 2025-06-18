#!/bin/bash

echo "Restarting Ubuntu Production Server"
echo "==================================="

# Server details
SERVER_IP="98.81.235.7"
APP_DIR="/var/www/itservicedesk"

# Check if we can connect to the server
echo "Checking server connectivity..."
if ! curl -s --connect-timeout 5 http://$SERVER_IP > /dev/null; then
    echo "❌ Cannot connect to server at $SERVER_IP"
    exit 1
fi

echo "✓ Server is reachable"

# Instructions for manual restart (since we can't SSH from here)
echo ""
echo "To restart the Ubuntu server application, run these commands on the server:"
echo ""
echo "# 1. Check PM2 status"
echo "pm2 status"
echo ""
echo "# 2. Check application logs"
echo "pm2 logs servicedesk --lines 20"
echo ""
echo "# 3. Restart the application"
echo "cd $APP_DIR"
echo "pm2 restart servicedesk"
echo ""
echo "# 4. If restart fails, rebuild and restart"
echo "npm run build"
echo "pm2 delete servicedesk"
echo "pm2 start ecosystem.config.js"
echo ""
echo "# 5. Check nginx status"
echo "sudo systemctl status nginx"
echo "sudo nginx -t"
echo ""
echo "# 6. Restart nginx if needed"
echo "sudo systemctl restart nginx"
echo ""
echo "Common issues and fixes:"
echo "- Port conflict: Check if port 3000 is in use"
echo "- Database connection: Verify PostgreSQL is running"
echo "- Build issues: Clear node_modules and reinstall"
echo "- Environment variables: Check .env file exists"

# Test if server comes back online
echo ""
echo "After restart, verify with:"
echo "curl -k https://$SERVER_IP/api/auth/me"
echo "Should return: {\"message\":\"Not authenticated\"}"