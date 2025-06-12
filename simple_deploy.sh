#!/bin/bash

# Simple deployment of Department and Business Unit changes
echo "Deploying Department and Business Unit changes to production server..."

# First, let's update the database schema on the server
echo "Updating database schema..."
ssh ubuntu@54.160.177.174 << 'EOF'
cd /home/ubuntu/servicedesk
npx drizzle-kit push
EOF

echo "Database schema updated successfully!"

# Copy updated component files
echo "Uploading updated files..."

# Copy schema file
scp shared/schema.ts ubuntu@54.160.177.174:/home/ubuntu/servicedesk/shared/

# Copy component files
scp client/src/components/ticket-form.tsx ubuntu@54.160.177.174:/home/ubuntu/servicedesk/client/src/components/
scp client/src/components/anonymous-ticket-form.tsx ubuntu@54.160.177.174:/home/ubuntu/servicedesk/client/src/components/
scp client/src/components/ticket-details-modal.tsx ubuntu@54.160.177.174:/home/ubuntu/servicedesk/client/src/components/
scp client/src/components/tickets-list.tsx ubuntu@54.160.177.174:/home/ubuntu/servicedesk/client/src/components/

# Restart the application
echo "Restarting application..."
ssh ubuntu@54.160.177.174 << 'EOF'
cd /home/ubuntu/servicedesk
pm2 restart servicedesk
pm2 logs servicedesk --lines 3
EOF

echo "Deployment completed! Department and Business Unit fields are now live on production."
echo "Visit: http://54.160.177.174:5000"