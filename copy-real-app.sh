#!/bin/bash

# Copy real IT Service Desk application to Ubuntu server
set -e

echo "=== Copying Real IT Service Desk Application ==="

# Create temporary archive of the real application
echo "1. Creating application archive..."
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

echo "2. Archive created: /tmp/itservicedesk-real.tar.gz"
ls -lh /tmp/itservicedesk-real.tar.gz

echo ""
echo "3. To deploy your REAL application to Ubuntu server:"
echo ""
echo "   # Copy archive to server"
echo "   scp /tmp/itservicedesk-real.tar.gz root@98.81.235.7:/tmp/"
echo ""
echo "   # On Ubuntu server, extract and deploy"
echo "   ssh root@98.81.235.7 << 'COMMANDS'"
echo "   cd /opt/itservicedesk"
echo "   sudo docker compose down"
echo "   tar -xzf /tmp/itservicedesk-real.tar.gz"
echo "   sudo docker compose up --build -d"
echo "   COMMANDS"
echo ""
echo "This will deploy your complete application with:"
echo "- React frontend with Tailwind CSS and shadcn/ui"
echo "- Express backend with all API routes"
echo "- Drizzle ORM with PostgreSQL database"
echo "- File upload system"
echo "- Email notifications via SendGrid"
echo "- User authentication and roles"
echo "- Ticket management system"
echo "- Change management workflows"
echo "- SLA tracking and metrics"
echo "- Calpion branding and styling"