#!/bin/bash

echo "Fixing Ubuntu Server Build and PM2 Configuration"
echo "================================================"

cat << 'EOF'
# Run these commands on your Ubuntu server to fix the build issues:

# 1. Stop any running processes
pm2 delete all 2>/dev/null || true

# 2. Navigate to application directory
cd /var/www/itservicedesk

# 3. Install dependencies globally and locally
sudo npm install -g vite esbuild pm2
npm install

# 4. Fix the ecosystem.config.js file (convert to CommonJS format)
cat > ecosystem.config.js << 'ECOSYSTEM_EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: './dist/index.js',
    cwd: '/var/www/itservicedesk',
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

# 5. Create logs directory
mkdir -p logs

# 6. Build the application
npm run build

# 7. Start the application
pm2 start ecosystem.config.js

# 8. Save PM2 configuration
pm2 save

# 9. Check status
pm2 status

# 10. View logs to verify everything is working
pm2 logs servicedesk --lines 10

# 11. Test the application
sleep 5
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.user","password":"password123"}'

EOF

echo ""
echo "Alternative: If vite is still not found, use this manual build process:"
echo ""
cat << 'EOF'
# Manual build process (if vite installation fails):

# Build frontend manually
cd /var/www/itservicedesk
npx vite build

# Build backend manually  
npx esbuild server/index.ts --platform=node --packages=external --bundle --format=esm --outdir=dist

# Then start with PM2
pm2 start ecosystem.config.js

EOF

echo "This should resolve:"
echo "- vite command not found error"
echo "- PM2 ecosystem.config.js format issues"
echo "- Authentication system deployment"
echo "- Port binding conflicts"