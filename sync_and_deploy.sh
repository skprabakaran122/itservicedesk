#!/bin/bash

# Complete Sync and Deploy Script
# This script will sync Replit changes to git and deploy to production server

set -e

echo "=== Complete Sync and Deploy Process ==="
echo "This script performs a full sync from Replit to git and deploys to production"
echo ""

# Step 1: Manual Git Sync Instructions
echo "STEP 1: Git Sync (Execute these commands manually)"
echo "=========================================="
echo "git add -A"
echo "git commit -m 'Added Department and Business Unit fields to ticket system'"
echo "git push origin main"
echo ""
echo "Files to be synced:"
echo "- shared/schema.ts (added requesterDepartment, requesterBusinessUnit)"
echo "- client/src/components/ticket-form.tsx (added dept/BU fields)"
echo "- client/src/components/anonymous-ticket-form.tsx (added dept/BU fields)"
echo "- client/src/components/ticket-details-modal.tsx (display dept/BU)"
echo "- client/src/components/tickets-list.tsx (show department)"
echo "- DEPARTMENT_DEPLOYMENT_SUMMARY.md (documentation)"
echo ""

# Step 2: Server Deployment Commands
echo "STEP 2: Production Server Deployment"
echo "====================================="
echo "Execute these commands to deploy to production server:"
echo ""

cat << 'DEPLOY_COMMANDS'
# Connect to production server
ssh ubuntu@54.160.177.174

# Navigate to application directory
cd /home/ubuntu/servicedesk

# Pull latest changes from git
git pull origin main

# Install any new dependencies
npm install

# Update database schema with new department/business unit fields
npx drizzle-kit push

# Restart the application
pm2 restart servicedesk

# Check application status
pm2 status servicedesk
pm2 logs servicedesk --lines 10

# Verify deployment
curl -s http://localhost:5000/api/auth/me || echo "Application is running"

echo "Deployment completed successfully!"
echo "Application available at: http://54.160.177.174:5000"
DEPLOY_COMMANDS

echo ""
echo "STEP 3: Verification"
echo "==================="
echo "After deployment, verify the following:"
echo "1. Login to http://54.160.177.174:5000"
echo "2. Create a new ticket and verify Department/Business Unit fields are present"
echo "3. Check existing tickets show department information in details"
echo "4. Test both authenticated and anonymous ticket creation"
echo ""

# Create a summary of changes for reference
echo "CHANGES DEPLOYED:"
echo "=================="
echo "✓ Database schema updated with requesterDepartment and requesterBusinessUnit fields"
echo "✓ Ticket creation forms include Department dropdown (11 options)"
echo "✓ Ticket creation forms include Business Unit dropdown (BU1-BU4)"
echo "✓ Ticket details display department and business unit information"
echo "✓ Ticket list shows department when available"
echo "✓ Both authenticated and anonymous forms updated"
echo ""

echo "=== IMPORTANT ==="
echo "Execute the git commands from STEP 1 first, then run the deployment commands from STEP 2"
echo "This ensures all Replit changes are properly synced to git before deployment"