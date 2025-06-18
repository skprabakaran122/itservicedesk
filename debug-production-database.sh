#!/bin/bash

echo "Debugging production database issues..."

# Test database connectivity
echo "1. Testing database connection:"
sudo -u postgres psql -d servicedesk -c "SELECT version();" 2>/dev/null || echo "Database connection failed"

# Check if database exists
echo "2. Checking database and user:"
sudo -u postgres psql -c "SELECT datname FROM pg_database WHERE datname='servicedesk';"
sudo -u postgres psql -c "SELECT usename FROM pg_user WHERE usename='servicedesk';"

# Check existing tables
echo "3. Checking existing tables:"
sudo -u postgres psql -d servicedesk -c "\dt" 2>/dev/null

# Check settings table specifically
echo "4. Checking settings table:"
sudo -u postgres psql -d servicedesk -c "SELECT * FROM settings;" 2>/dev/null || echo "Settings table missing"

# Check changes table
echo "5. Checking changes table:"
sudo -u postgres psql -d servicedesk -c "\d changes" 2>/dev/null || echo "Changes table missing"

# Test direct database connection with app credentials
echo "6. Testing app database connection:"
PGPASSWORD=servicedesk123 psql -h localhost -U servicedesk -d servicedesk -c "SELECT current_user, current_database();" 2>/dev/null || echo "App database connection failed"

# Check server logs for errors
echo "7. Recent PM2 logs:"
pm2 logs servicedesk --lines 20 --nostream 2>/dev/null || echo "No PM2 logs available"

# Test API endpoints directly
echo "8. Testing API endpoints:"

# Login first
LOGIN_RESPONSE=$(curl -s -c /tmp/debug_cookies.txt -X POST http://localhost:5000/api/auth/login -H "Content-Type: application/json" -d '{"username":"john.doe","password":"password123"}')
echo "Login response: $LOGIN_RESPONSE"

# Test email settings
EMAIL_RESPONSE=$(curl -s -b /tmp/debug_cookies.txt http://localhost:5000/api/email/settings)
echo "Email settings response: $EMAIL_RESPONSE"

# Test email save
EMAIL_SAVE_RESPONSE=$(curl -s -b /tmp/debug_cookies.txt -X POST http://localhost:5000/api/email/settings -H "Content-Type: application/json" -d '{"provider":"sendgrid","sendgridApiKey":"test-key","fromEmail":"test@calpion.com"}')
echo "Email save response: $EMAIL_SAVE_RESPONSE"

# Test change creation
CHANGE_RESPONSE=$(curl -s -b /tmp/debug_cookies.txt -X POST http://localhost:5000/api/changes -H "Content-Type: application/json" -d '{"title":"Test Change","description":"Test description","reason":"Testing"}')
echo "Change creation response: $CHANGE_RESPONSE"

# Cleanup
rm -f /tmp/debug_cookies.txt

echo "Debug complete. Check above for specific error messages."