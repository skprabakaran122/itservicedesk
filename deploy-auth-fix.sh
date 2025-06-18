#!/bin/bash

echo "Deploying Authentication Fix to Ubuntu Server"
echo "============================================="

cat << 'EOF'
# Run these commands on your Ubuntu server (98.81.235.7):

# 1. Stop the current application to resolve port conflict
pm2 delete servicedesk

# 2. Navigate to application directory
cd /var/www/itservicedesk

# 3. Pull the latest code with authentication fixes
git pull origin main

# 4. Install any new dependencies (bcrypt for password handling)
npm install

# 5. Rebuild the application
npm run build

# 6. Start the application fresh
pm2 start ecosystem.config.js

# 7. Check if it's running properly
pm2 status
pm2 logs servicedesk --lines 10

# 8. Test the authentication fix
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.user","password":"password123"}'

# Expected response: Should return user data instead of "Invalid credentials"

# 9. Test external access
curl -k https://98.81.235.7/api/auth/me

# 10. If still having port conflicts, check what's using port 3000:
# sudo netstat -tulpn | grep :3000
# sudo fuser -k 3000/tcp  # (if needed to kill conflicting process)

EOF

echo ""
echo "Key Changes Being Deployed:"
echo "✓ Fixed authentication system to handle both bcrypt and plain text passwords"
echo "✓ Environment-specific port configuration (3000 for production)"
echo "✓ Proper password validation logic"
echo ""
echo "Available Test Credentials:"
echo "- Username: test.user | Password: password123"
echo "- Username: test.admin | Password: password123" 
echo "- Username: john.doe | Password: password123"
echo ""
echo "After deployment, the 502 Bad Gateway and login issues should be resolved."