#!/bin/bash

echo "Quick Ubuntu Build Fix"
echo "====================="

cat << 'EOF'
# Run these commands on Ubuntu server:

cd /var/www/itservicedesk

# Install build dependencies
npm install vite esbuild

# Verify they're installed
echo "Checking installed build tools:"
ls -la node_modules/.bin/ | grep -E "(vite|esbuild)"

# Build the application
echo "Building frontend..."
npx vite build

echo "Building backend..."
npx esbuild server/index.ts --platform=node --packages=external --bundle --format=esm --outdir=dist

# Check build output
echo "Build output:"
ls -la dist/

# Restart with fresh build
pm2 restart servicedesk

# Test application
sleep 5
curl -s http://localhost:5000/api/auth/me | head -20

echo ""
echo "PM2 Status:"
pm2 status

EOF