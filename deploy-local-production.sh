#!/bin/bash

# Deploy IT Service Desk locally in current directory
set -e

echo "=== Deploying IT Service Desk (Local Production) ==="
echo "Directory: $(pwd)"
echo "Using existing server.cjs + PM2 configuration"
echo ""

# Stop existing PM2 processes
echo "Stopping existing PM2 processes..."
pm2 stop all 2>/dev/null || true
pm2 delete all 2>/dev/null || true

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    npm install
fi

# Install tsx globally if not present
if ! command -v tsx &> /dev/null; then
    echo "Installing tsx for TypeScript execution..."
    npm install -g tsx
fi

# Build frontend
echo "Building frontend..."
npm run build

# Create logs directory
mkdir -p logs

# Set up environment
echo "Configuring environment..."
cat > .env << 'EOF'
NODE_ENV=production
PORT=5000
DATABASE_URL=postgresql://servicedesk:SecurePass123@localhost:5432/servicedesk
SENDGRID_API_KEY=SG.placeholder
EOF

# Start with PM2
echo "Starting application with PM2..."
pm2 start ecosystem.config.cjs

# Show status
echo ""
echo "=== Deployment Complete ==="
echo "Application running locally on port 5000"
echo ""
echo "Login credentials:"
echo "  Admin: test.admin / password123"
echo "  User:  test.user / password123"
echo ""
echo "PM2 Status:"
pm2 status
echo ""
echo "Application logs (last 10 lines):"
pm2 logs --lines 10

echo ""
echo "Testing application health..."
sleep 3
curl -s http://localhost:5000/health | jq . 2>/dev/null || echo "Health check response received"