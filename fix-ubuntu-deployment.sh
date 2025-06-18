#!/bin/bash

echo "Ubuntu Server Recovery Script"
echo "============================="

# Since we can't SSH from here, this script provides the exact commands
# to run on the Ubuntu server to fix the 502 error

cat << 'EOF'
# Run these commands on your Ubuntu server (98.81.235.7):

# 1. Check current PM2 status
pm2 status

# 2. Check application logs for errors
pm2 logs servicedesk --lines 50

# 3. Navigate to application directory
cd /var/www/itservicedesk

# 4. Check if the application files are present
ls -la

# 5. Stop and remove existing PM2 process
pm2 delete servicedesk

# 6. Rebuild the application
npm install --production
npm run build

# 7. Verify build completed
ls -la dist/

# 8. Start fresh PM2 process
pm2 start ecosystem.config.js

# 9. Save PM2 configuration
pm2 save

# 10. Check if application is running
pm2 status
pm2 logs servicedesk --lines 10

# 11. Test local application response
curl http://localhost:3000/api/auth/me

# 12. If still failing, check database connection
sudo systemctl status postgresql
psql -h localhost -U servicedesk -d servicedesk -c "SELECT 1;"

# 13. Restart Nginx
sudo nginx -t
sudo systemctl restart nginx

# 14. Test external access
curl -k https://98.81.235.7/api/auth/me

# Expected response: {"message":"Not authenticated"}
EOF

echo ""
echo "Most likely causes of 502 error:"
echo "1. PM2 process crashed due to database connection issues"
echo "2. Application port conflict (trying to use port already in use)"
echo "3. Environment variables missing (.env file)"
echo "4. Build artifacts corrupted or missing"
echo ""
echo "After running the above commands, the server should respond with:"
echo '{"message":"Not authenticated"} instead of 502 error'