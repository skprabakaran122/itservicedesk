#!/bin/bash

# Quick deployment fix for PM2 configuration issue
echo "🚀 Starting fresh deployment fix..."

# Stop any existing PM2 processes
pm2 stop all 2>/dev/null || true
pm2 delete all 2>/dev/null || true

# Create required directories
mkdir -p logs

# Set environment variables if not already set
export NODE_ENV=production
export PORT=5000

echo "📦 Installing dependencies..."
npm install --production

echo "🏗️ Building application..."
npm run build

echo "📂 Moving build files to correct location..."
mkdir -p server/public
if [ -d "dist/public" ]; then
    cp -r dist/public/* server/public/
    echo "✅ Build files moved to server/public"
else
    echo "⚠️ No dist/public directory found, checking for alternative locations..."
    if [ -d "dist" ]; then
        cp -r dist/* server/public/
        echo "✅ Build files moved from dist/ to server/public"
    fi
fi

echo "🗄️ Setting up database..."
npm run db:push

echo "🎯 Starting application with PM2..."

# Try method 1: Using .cjs config
if pm2 start ecosystem.config.cjs; then
    echo "✅ Started with ecosystem.config.cjs"
elif pm2 start ecosystem.config.js; then
    echo "✅ Started with ecosystem.config.js"
else
    echo "⚠️ Config file failed, using direct command..."
    # Method 2: Direct PM2 command
    pm2 start server/index.ts \
        --name servicedesk \
        --interpreter node \
        --interpreter-args "--import tsx" \
        --env production \
        --max-memory-restart 1G \
        --restart-delay 4000 \
        --max-restarts 5 \
        --min-uptime 10s
fi

# Save PM2 configuration
pm2 save

echo "📊 Application status:"
pm2 status

echo "📋 Recent logs:"
pm2 logs servicedesk --lines 10

echo "🎉 Deployment complete!"
echo "Access your application at: http://54.160.177.174:5000"
echo "Admin login: john.doe / password123"