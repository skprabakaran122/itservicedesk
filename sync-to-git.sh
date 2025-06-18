#!/bin/bash

echo "IT Service Desk - Git Sync Script"
echo "================================="

# Exit on any error
set -e

# Get repository URL from user if not provided
if [ -z "$1" ]; then
    echo "Usage: $0 <git-repository-url> [branch-name]"
    echo "Example: $0 https://github.com/username/servicedesk.git main"
    exit 1
fi

REPO_URL="$1"
BRANCH="${2:-main}"

echo "Repository URL: $REPO_URL"
echo "Branch: $BRANCH"

# Initialize git if not already done
if [ ! -d ".git" ]; then
    echo "Initializing Git repository..."
    git init
    git remote add origin "$REPO_URL"
else
    echo "Git repository already initialized"
    # Update remote URL if different
    git remote set-url origin "$REPO_URL"
fi

# Stage all files
echo "Staging files for commit..."
git add .

# Check if there are changes to commit
if git diff --staged --quiet; then
    echo "No changes to commit"
else
    # Commit changes
    echo "Committing changes..."
    git commit -m "Clean repository sync - IT Service Desk application

Features:
- Complete IT Service Desk with ticket management
- Change request approval workflows
- User management with role-based access
- SLA tracking and metrics
- Email notifications with SendGrid
- PostgreSQL database with Drizzle ORM
- React frontend with TypeScript
- Express backend with authentication
- Production-ready deployment scripts

Deployment:
- Run ./deploy.sh for complete setup
- Supports both development (Neon) and production (local PostgreSQL)
- Includes PM2 process management and Nginx configuration
- Automated firewall and security setup"
fi

# Push to repository
echo "Pushing to remote repository..."
git branch -M "$BRANCH"
git push -u origin "$BRANCH"

echo ""
echo "✅ Repository synced successfully!"
echo "Repository: $REPO_URL"
echo "Branch: $BRANCH"
echo ""
echo "Deployment instructions:"
echo "1. Clone repository on target server"
echo "2. Run: chmod +x deploy.sh && ./deploy.sh [server-ip]"
echo "3. Application will be available at http://[server-ip]"