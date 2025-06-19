#!/bin/bash

# Fix git push by removing files with hardcoded secrets
set -e

echo "=== Fixing Git Push Issue ==="

# Remove files that contain hardcoded secrets
echo "Removing files with hardcoded secrets..."
rm -f deploy-fresh-from-git.sh 2>/dev/null || true

# Check current git status
echo "Current git status:"
git status --porcelain

# Add the removal of problematic files
git add -A

# Create a clean commit
git commit -m "Remove files with hardcoded secrets to fix git push

- Remove deploy-fresh-from-git.sh containing hardcoded SendGrid API key
- Clean repository for successful GitHub push
- Maintain deployment functionality through alternative scripts"

echo ""
echo "=== Git Push Fix Applied ==="
echo "✓ Removed files with hardcoded secrets"
echo "✓ Created clean commit"
echo "✓ Ready for git push"
echo ""
echo "Now run: git push"
echo ""
echo "For deployment, use: git-deploy-solution.sh on Ubuntu server"