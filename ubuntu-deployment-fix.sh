#!/bin/bash

echo "Complete Ubuntu Server Deployment Fix"
echo "====================================="

cat << 'EOF'
# Complete fix for Ubuntu server deployment issues
# Run these commands on your Ubuntu server (98.81.235.7):

# 1. Clean up existing processes and conflicts
pm2 delete all 2>/dev/null || true
sudo fuser -k 3000/tcp 2>/dev/null || true

# 2. Navigate to application directory
cd /var/www/itservicedesk

# 3. Install missing global dependencies
sudo npm install -g vite@latest esbuild@latest pm2@latest

# 4. Clean and reinstall local dependencies
rm -rf node_modules package-lock.json
npm install

# 5. Create proper ecosystem configuration
cat > ecosystem.config.js << 'ECOSYSTEM_EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: './dist/index.js',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production',
      PORT: 3000,
      DATABASE_URL: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk'
    },
    error_file: './logs/error.log',
    out_file: './logs/out.log',
    log_file: './logs/combined.log',
    time: true
  }]
};
ECOSYSTEM_EOF

# 6. Create logs directory
mkdir -p logs

# 7. Build the application
echo "Building application..."
npm run build

# 8. Verify build artifacts exist
if [ ! -f "dist/index.js" ]; then
    echo "Build failed - trying manual build"
    npx vite build
    npx esbuild server/index.ts --platform=node --packages=external --bundle --format=esm --outdir=dist
fi

# 9. Start the application
pm2 start ecosystem.config.js

# 10. Save PM2 configuration
pm2 save

# 11. Setup PM2 startup script
pm2 startup

# 12. Check application status
echo "Application status:"
pm2 status

# 13. Wait for startup and check logs
sleep 10
echo "Recent logs:"
pm2 logs servicedesk --lines 15

# 14. Test authentication endpoint
echo "Testing authentication..."
AUTH_RESULT=$(curl -s -w "%{http_code}" -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.user","password":"password123"}')

echo "Auth test result: $AUTH_RESULT"

# 15. Test external access
echo "Testing external access..."
curl -k -s -w "Response code: %{http_code}\n" https://98.81.235.7/api/auth/me

# 16. Final status check
echo ""
echo "Final system status:"
pm2 status
sudo systemctl status nginx

EOF

echo ""
echo "This script will:"
echo "- Install missing build tools (vite, esbuild)"
echo "- Fix PM2 configuration format issues"
echo "- Deploy authentication system fixes"
echo "- Resolve port binding conflicts"
echo "- Test login functionality"
echo ""
echo "After running, you should be able to login with:"
echo "Username: test.user | Password: password123"