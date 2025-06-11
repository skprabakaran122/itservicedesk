#!/bin/bash

# Force deployment script to sync modal changes to server

echo "=== Forcing Modal Changes Deployment ==="

# Step 1: Clean Git state
echo "Cleaning Git locks..."
rm -f .git/index.lock .git/config.lock

# Step 2: Force add modal files
echo "Adding modal files..."
git add -f client/src/components/ticket-form.tsx client/src/components/change-form.tsx

# Step 3: Create new commit
echo "Creating commit..."
git commit -m "FORCE: Deploy modal scroll and outside-click prevention

Key changes:
- ticket-form.tsx: max-h-[90vh] overflow-y-auto, onInteractOutside preventDefault
- change-form.tsx: max-h-[90vh] overflow-y-auto, onInteractOutside preventDefault
- Both modals maintain proper close functionality"

# Step 4: Force push
echo "Pushing to repository..."
git push origin main

echo "=== Git deployment complete ==="
echo ""
echo "Now run on Ubuntu server:"
echo "cd /home/ubuntu/servicedesk"
echo "git pull origin main"
echo "pm2 restart servicedesk"
echo "pm2 logs servicedesk --lines 5"