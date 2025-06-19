#!/bin/bash

# Comprehensive verification of IT Service Desk deployment
set -e

cd /var/www/itservicedesk

echo "=== IT Service Desk Deployment Verification ==="

# Check PM2 status
echo "1. PM2 Application Status:"
pm2 status | grep servicedesk || echo "❌ PM2 servicedesk not running"

# Check application health
echo ""
echo "2. Application Health Check:"
if curl -s http://localhost:5000/api/health >/dev/null 2>&1; then
    echo "✓ Application responding on port 5000"
    curl -s http://localhost:5000/api/health | jq . 2>/dev/null || curl -s http://localhost:5000/api/health
else
    echo "❌ Application not responding on port 5000"
fi

# Check nginx status
echo ""
echo "3. Nginx Status:"
systemctl is-active nginx && echo "✓ Nginx running" || echo "❌ Nginx not running"

# Check nginx proxy
echo ""
echo "4. Nginx Proxy Test:"
if curl -s http://localhost/ | grep -q "Calpion\|Service Desk\|Login"; then
    echo "✓ Nginx proxying to IT Service Desk"
elif curl -s http://localhost/ | grep -q "Welcome to nginx"; then
    echo "❌ Nginx showing default page - proxy not configured"
else
    echo "❌ Nginx proxy not working"
fi

# Check external access
echo ""
echo "5. External Access Test:"
if curl -s http://98.81.235.7/ | grep -q "Calpion\|Service Desk\|Login"; then
    echo "✓ External access working"
elif curl -s http://98.81.235.7/ | grep -q "Welcome to nginx"; then
    echo "❌ External access shows nginx default page"
else
    echo "❌ External access not working"
fi

# Check database connectivity
echo ""
echo "6. Database Connectivity:"
if curl -s http://localhost:5000/api/users | grep -q "test.admin\|test.user"; then
    echo "✓ Database connected and populated"
else
    echo "❌ Database connection issue"
fi

# Check authentication
echo ""
echo "7. Authentication Test:"
if curl -s -X POST http://localhost:5000/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"username":"test.admin","password":"password123"}' | grep -q "success\|user"; then
    echo "✓ Authentication working"
else
    echo "❌ Authentication not working"
fi

# Memory usage
echo ""
echo "8. Resource Usage:"
pm2 show servicedesk | grep -E "memory|cpu" || echo "PM2 details not available"

echo ""
echo "=== Deployment Summary ==="
if curl -s http://98.81.235.7/ | grep -q "Calpion\|Service Desk\|Login"; then
    echo "🎉 IT Service Desk Successfully Deployed!"
    echo ""
    echo "Access your application:"
    echo "URL: http://98.81.235.7"
    echo "Admin: test.admin / password123"
    echo "User: test.user / password123"
    echo "Manager: john.doe / password123"
    echo ""
    echo "Features available:"
    echo "- Ticket management with SLA tracking"
    echo "- Change request workflows"
    echo "- Product catalog management"
    echo "- User administration"
    echo "- Email notifications (SendGrid configured)"
    echo "- Approval workflows"
else
    echo "❌ Deployment needs attention - run fix-nginx-proxy.sh"
fi