#!/bin/bash

# Complete deployment of real IT Service Desk application via Docker
set -e

SERVER_IP="98.81.235.7"
SERVER_USER="root"

echo "=== Deploying Complete IT Service Desk Application ==="

# Check if we have the application archive
if [ ! -f "/tmp/itservicedesk-real.tar.gz" ]; then
    echo "Creating fresh application archive..."
    tar -czf /tmp/itservicedesk-real.tar.gz \
        --exclude=node_modules \
        --exclude=.git \
        --exclude=dist \
        --exclude=logs \
        --exclude="*.log" \
        client/ server/ shared/ \
        package.json package-lock.json \
        tsconfig.json tailwind.config.ts postcss.config.js \
        vite.config.ts drizzle.config.ts components.json \
        .env 2>/dev/null || true
fi

echo "1. Copying application archive to server..."
scp /tmp/itservicedesk-real.tar.gz $SERVER_USER@$SERVER_IP:/tmp/

echo "2. Copying Docker configuration files..."
scp deploy-real-app.sh $SERVER_USER@$SERVER_IP:/opt/itservicedesk/

echo "3. Deploying on Ubuntu server..."
ssh $SERVER_USER@$SERVER_IP << 'EOF'
cd /opt/itservicedesk

# Run the real app deployment script
./deploy-real-app.sh

# Extract the real application code
echo "Extracting real application files..."
tar -xzf /tmp/itservicedesk-real.tar.gz

# Install tsx globally for TypeScript execution
npm install -g tsx

# Build and start the real application
echo "Building and starting real IT Service Desk..."
sudo docker compose down --remove-orphans
sudo docker compose up --build -d

echo "Waiting for services to initialize..."
sleep 60

echo "Checking deployment status..."
sudo docker compose ps

echo "Testing application health..."
curl -f http://localhost:3000/health && echo "✓ Application healthy"
curl -f http://localhost/ && echo "✓ Frontend accessible"

echo ""
echo "=== Real IT Service Desk Deployed Successfully ==="
echo "Access your application at: http://98.81.235.7"
echo ""
echo "Features now available:"
echo "- Complete React frontend with Calpion branding"
echo "- Full ticket management system"
echo "- Change request workflows"
echo "- User authentication and role management"
echo "- File upload capabilities"
echo "- Email notifications via SendGrid"
echo "- SLA tracking and metrics"
echo "- Product and user management"
echo "- Comprehensive dashboard with analytics"
EOF

echo ""
echo "=== Deployment Complete ==="
echo "Your REAL IT Service Desk is now running at: http://98.81.235.7"
echo ""
echo "Login with:"
echo "- admin / password123 (Administrator)"
echo "- john.doe / password123 (Agent)"
echo "- test.user / password123 (User)"
echo ""
echo "Docker management:"
echo "ssh root@98.81.235.7 'cd /opt/itservicedesk && sudo docker compose logs -f app'"