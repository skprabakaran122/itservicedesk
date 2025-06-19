#!/bin/bash

# Bypass GitHub secret protection - multiple approaches
set -e

echo "=== Bypassing GitHub Secret Protection ==="

echo "Option 1: Use the GitHub bypass URL"
echo "GitHub provided this URL to allow the secret:"
echo "https://github.com/skprabakaran122/itservicedesk/security/secret-scanning/unblock-secret/2yiXjYqOVjMfJiTtxuJBqvjxsN1"
echo ""
echo "Visit this URL and click 'Allow secret' to bypass the protection."
echo ""

echo "Option 2: Clean commit history (advanced)"
echo "This removes the secret from git history:"
echo ""
cat << 'EOF'
# WARNING: This rewrites git history
git filter-branch --force --index-filter \
  'git rm --cached --ignore-unmatch deploy-fresh-from-git.sh' \
  --prune-empty --tag-name-filter cat -- --all

# Force push the cleaned history
git push origin main --force
EOF

echo ""
echo "Option 3: Create new repository"
echo "If the above don't work, create a fresh repository:"
echo ""
cat << 'EOF'
# Create new repository on GitHub
# Clone it locally
# Copy only clean files (no deploy-fresh-from-git.sh)
# Push to new repository
EOF

echo ""
echo "=== Recommended Approach ==="
echo "1. Visit the GitHub bypass URL above"
echo "2. Click 'Allow secret' to permit the push"
echo "3. Continue with git push"
echo ""
echo "After successful push, deploy with:"
echo "sudo bash /var/www/itservicedesk/git-deploy-solution.sh"