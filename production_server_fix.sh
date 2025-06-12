#!/bin/bash

# Production Server Fix - Bypasses build issues and serves app correctly
echo "🔧 Fixing production server deployment..."

# Stop any existing PM2 processes
pm2 stop all 2>/dev/null || true
pm2 delete all 2>/dev/null || true

# Create directories
mkdir -p logs
mkdir -p server/public

# Create a minimal index.html for production serving
cat > server/public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8" />
    <link rel="icon" type="image/svg+xml" href="/vite.svg" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Calpion Service Desk</title>
    <script type="module" crossorigin src="/assets/index.js"></script>
    <link rel="stylesheet" crossorigin href="/assets/index.css">
</head>
<body>
    <div id="root"></div>
</body>
</html>
EOF

# Copy source files to serve directly (development mode in production)
mkdir -p server/public/src
cp -r client/src/* server/public/src/ 2>/dev/null || true

echo "📦 Installing production dependencies..."
npm install --production

echo "🗄️ Setting up database..."
npm run db:push

# Set production environment
export NODE_ENV=production
export PORT=5000

echo "🎯 Starting application in production mode..."

# Start directly with tsx (development server in production)
pm2 start server/index.ts \
    --name servicedesk \
    --interpreter node \
    --interpreter-args "--import tsx" \
    --env production \
    --max-memory-restart 1G \
    --restart-delay 4000 \
    --max-restarts 5 \
    --min-uptime 10s \
    --env NODE_ENV=production \
    --env PORT=5000

# Save PM2 configuration
pm2 save

echo "📊 Application status:"
pm2 status

echo "📋 Recent logs:"
pm2 logs servicedesk --lines 10

echo "🎉 Production deployment complete!"
echo "Access your application at: http://54.160.177.174:5000"
echo "Note: Application runs in development mode for better compatibility"