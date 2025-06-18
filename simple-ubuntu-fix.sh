#!/bin/bash

echo "Simple Ubuntu Server Fix - Install Missing Build Tools"
echo "===================================================="

cat << 'EOF'
# Run on Ubuntu server to install missing build dependencies:

cd /var/www/itservicedesk

# Check current status
echo "Current PM2 status:"
pm2 status

# Install missing build tools
echo "Installing build dependencies..."
npm install vite esbuild

# Verify installation
ls -la node_modules/.bin/ | grep -E "(vite|esbuild)"

# Build application with installed tools
echo "Building application..."
./node_modules/.bin/vite build
./node_modules/.bin/esbuild server/index.ts --platform=node --packages=external --bundle --format=esm --outdir=dist

# Restart application with fresh build
pm2 restart servicedesk

# Test the updated application
sleep 10
echo "Testing updated application..."
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.user","password":"password123"}'

echo ""
echo "Application status after update:"
pm2 status

EOF

echo ""
echo "This will:"
echo "- Install vite and esbuild locally"
echo "- Build the application properly"
echo "- Restart with updated code"
echo "- Test authentication system"