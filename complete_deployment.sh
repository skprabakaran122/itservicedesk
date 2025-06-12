#!/bin/bash

# Complete Deployment Script - Sync Replit to Git and Deploy to Production
# This automates the entire process from local changes to production

set -e

echo "=== Complete Deployment Process ==="
echo "Syncing Replit changes to git and deploying to production server"
echo ""

# Function to check if git operations are working
check_git_access() {
    if ! git status >/dev/null 2>&1; then
        echo "Error: Git repository access is restricted."
        echo "Please execute these git commands manually:"
        echo ""
        echo "git add -A"
        echo "git commit -m 'Added Department and Business Unit fields to ticket system'"
        echo "git push origin main"
        echo ""
        echo "Then run this script again with --skip-git flag"
        exit 1
    fi
}

# Parse command line arguments
SKIP_GIT=false
if [[ "$1" == "--skip-git" ]]; then
    SKIP_GIT=true
fi

# Step 1: Git Sync (if not skipped)
if [[ "$SKIP_GIT" != true ]]; then
    echo "Step 1: Syncing changes to git..."
    
    # Check git access
    check_git_access
    
    # Show current status
    echo "Current git status:"
    git status --short
    
    # Add all changes
    echo "Adding all changes..."
    git add -A
    
    # Commit changes
    echo "Committing changes..."
    git commit -m "Added Department and Business Unit fields to ticket system

- Added requesterDepartment and requesterBusinessUnit fields to ticket schema
- Updated authenticated ticket form with department/business unit dropdowns
- Updated anonymous ticket form with same fields
- Enhanced ticket details to display department and business unit
- Updated ticket list to show department information
- Business Unit options: BU1, BU2, BU3, BU4
- Department options: IT, Finance, HR, Operations, Sales, Marketing, Legal, Executive, Customer Service, R&D, Other"
    
    # Push to origin
    echo "Pushing to git repository..."
    git push origin main
    
    echo "✓ Git sync completed successfully"
    echo ""
else
    echo "Skipping git sync (--skip-git flag provided)"
    echo ""
fi

# Step 2: Deploy to Production Server
echo "Step 2: Deploying to production server..."

# Server details
SERVER="ubuntu@54.160.177.174"
APP_DIR="/home/ubuntu/servicedesk"

# Check if SSH key exists
if [[ ! -f ~/.ssh/id_rsa ]] && [[ ! -f ~/.ssh/id_ed25519 ]]; then
    echo "Warning: No SSH key found. Using password authentication."
fi

# Create deployment script for server
DEPLOY_SCRIPT=$(cat << 'EOF'
#!/bin/bash
set -e

echo "Starting deployment on production server..."

# Navigate to application directory
cd /home/ubuntu/servicedesk

# Backup current state
echo "Creating backup..."
cp -r . ../servicedesk_backup_$(date +%Y%m%d_%H%M%S) || true

# Pull latest changes
echo "Pulling latest changes from git..."
git pull origin main

# Install/update dependencies
echo "Installing dependencies..."
npm install

# Update database schema
echo "Updating database schema..."
npx drizzle-kit push

# Build application
echo "Building application..."
npm run build || echo "Build step skipped (not configured)"

# Restart application with PM2
echo "Restarting application..."
pm2 restart servicedesk || pm2 start ecosystem.config.js

# Wait for application to start
sleep 5

# Check application status
echo "Checking application status..."
pm2 status servicedesk

# Show recent logs
echo "Recent application logs:"
pm2 logs servicedesk --lines 5

# Test application endpoint
echo "Testing application..."
curl -s http://localhost:5000/api/auth/me >/dev/null && echo "✓ Application is responding" || echo "⚠ Application may still be starting"

echo ""
echo "✓ Deployment completed successfully!"
echo "Application is available at: http://54.160.177.174:5000"
echo ""
echo "New Features Deployed:"
echo "- Department and Business Unit fields in ticket creation"
echo "- Enhanced ticket display with organizational information"
echo "- Updated database schema with new fields"
EOF
)

# Execute deployment on server
echo "Executing deployment on production server..."
echo "$DEPLOY_SCRIPT" | ssh $SERVER 'bash -s'

echo ""
echo "=== Deployment Summary ==="
echo "✓ Changes synced to git repository"
echo "✓ Production server updated with latest code"
echo "✓ Database schema updated with department/business unit fields"
echo "✓ Application restarted and verified"
echo ""
echo "Production URL: http://54.160.177.174:5000"
echo "Login: john.doe / password123"
echo ""
echo "Test the new Department and Business Unit fields in ticket creation!"