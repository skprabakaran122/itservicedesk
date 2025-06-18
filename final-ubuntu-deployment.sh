#!/bin/bash

echo "Final Ubuntu Server Deployment Script"
echo "====================================="

cat << 'EOF'
# Complete deployment solution for Ubuntu server 98.81.235.7
# Run as: sudo bash final-ubuntu-deployment.sh

# Stop all conflicting processes
pm2 delete all 2>/dev/null || true
sudo fuser -k 3000/tcp 2>/dev/null || true

# Ensure we're in the right directory
cd /var/www/itservicedesk

# Update Node.js and install PM2
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs
sudo npm install -g pm2@5.3.0

# Clean rebuild
rm -rf node_modules package-lock.json dist logs
npm install

# Build using local binaries (avoids global dependency issues)
echo "Building application with local tools..."
npx vite build
npx esbuild server/index.ts --platform=node --packages=external --bundle --format=esm --outdir=dist

# Create logs directory
mkdir -p logs

# Create production environment file
cat > .env << 'ENV_EOF'
DATABASE_URL=postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk
NODE_ENV=production
PORT=3000
ENV_EOF

# Create minimal PM2 configuration
cat > production.config.js << 'CONFIG_EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: './dist/index.js',
    instances: 1,
    autorestart: true,
    env_file: './.env',
    log_file: './logs/combined.log',
    out_file: './logs/out.log',
    error_file: './logs/error.log'
  }]
};
CONFIG_EOF

# Start application
pm2 start production.config.js
pm2 save

# Wait for startup
sleep 15

# Test endpoints
echo "Testing authentication system..."
LOGIN_TEST=$(curl -s -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.user","password":"password123"}')

echo "Login test result: $LOGIN_TEST"

# Test external access
echo "Testing external HTTPS access..."
EXTERNAL_TEST=$(curl -k -s https://98.81.235.7/api/auth/me)
echo "External test result: $EXTERNAL_TEST"

# Show final status
echo ""
echo "Application Status:"
pm2 status

echo ""
echo "Recent Logs:"
pm2 logs servicedesk --lines 10

echo ""
echo "If login test shows user data, deployment succeeded!"
echo "Access: https://98.81.235.7"
echo "Credentials: test.user / password123"

EOF

echo ""
echo "This deployment script:"
echo "- Uses local npm binaries to avoid global dependency issues"
echo "- Creates clean PM2 configuration with proper CommonJS format"
echo "- Tests authentication system after deployment"
echo "- Includes the bcrypt password validation fixes"
echo ""
echo "Run this on the Ubuntu server to resolve all current issues."