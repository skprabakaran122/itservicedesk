#!/bin/bash

# Fix Production Server Issues
echo "=== Fixing Production Server Issues ==="

# Connect to production server and fix issues
cat << 'EOF'
# Execute these commands on the production server (ubuntu@54.160.177.174):

# 1. Fix SendGrid API Key Issue
echo "Fixing SendGrid API key configuration..."

# Check current environment variables
echo "Current environment variables:"
pm2 env 0

# Set proper SendGrid API key (replace with your actual key)
pm2 set SENDGRID_API_KEY "SG.your_actual_sendgrid_key_here"

# 2. Update application with latest changes
echo "Updating application..."
cd /home/ubuntu/servicedesk

# Pull latest changes
git pull origin main

# Update database schema for Department/Business Unit fields
npx drizzle-kit push

# 3. Restart application with proper environment
echo "Restarting application..."
pm2 restart servicedesk

# Wait for startup
sleep 5

# 4. Check application status
echo "Checking application status..."
pm2 status
pm2 logs servicedesk --lines 10

# 5. Test basic functionality
echo "Testing application..."
curl -s http://localhost:5000/api/products | head -20

echo ""
echo "=== Production Server Fixed ==="
echo "Application URL: http://54.160.177.174:5000"
echo "Login: john.doe / password123"
EOF