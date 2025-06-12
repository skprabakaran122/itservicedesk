#!/bin/bash

# Deploy Department and Business Unit Changes
# This script updates the production server with the latest changes

set -e

echo "=== Deploying Department and Business Unit Changes ==="

# Server details
SERVER_USER="ubuntu"
SERVER_IP="54.160.177.174"
APP_DIR="/home/ubuntu/servicedesk"

echo "Connecting to production server..."

# Create deployment package
echo "Creating deployment package..."
tar -czf department_changes.tar.gz \
  shared/schema.ts \
  client/src/components/ticket-form.tsx \
  client/src/components/anonymous-ticket-form.tsx \
  client/src/components/ticket-details-modal.tsx \
  client/src/components/tickets-list.tsx \
  drizzle.config.ts

# Upload and deploy changes
echo "Uploading changes to server..."
scp -i ~/.ssh/id_rsa department_changes.tar.gz ${SERVER_USER}@${SERVER_IP}:/tmp/

echo "Deploying changes on server..."
ssh -i ~/.ssh/id_rsa ${SERVER_USER}@${SERVER_IP} << 'EOF'
  cd /home/ubuntu/servicedesk
  
  # Backup current files
  cp -r shared/schema.ts shared/schema.ts.backup.$(date +%Y%m%d_%H%M%S)
  cp -r client/src/components client/src/components.backup.$(date +%Y%m%d_%H%M%S)
  
  # Extract new files
  cd /tmp
  tar -xzf department_changes.tar.gz
  
  # Copy new files
  cp shared/schema.ts /home/ubuntu/servicedesk/shared/
  cp client/src/components/* /home/ubuntu/servicedesk/client/src/components/
  
  # Update database schema
  cd /home/ubuntu/servicedesk
  npm run db:push
  
  # Restart application
  pm2 restart servicedesk
  
  echo "Deployment completed successfully!"
  pm2 logs servicedesk --lines 5
EOF

# Cleanup
rm department_changes.tar.gz

echo "=== Deployment Complete ==="
echo "Department and Business Unit fields have been deployed to production"
echo "Server: http://54.160.177.174:5000"