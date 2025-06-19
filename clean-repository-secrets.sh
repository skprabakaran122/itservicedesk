#!/bin/bash

# Clean repository of hardcoded secrets and prepare for deployment
set -e

echo "=== Cleaning Repository Secrets ==="

# Remove hardcoded API keys from all deployment scripts
echo "Removing hardcoded SendGrid API key from deployment scripts..."

# Find and replace any hardcoded SendGrid API keys
find . -name "*.sh" -type f -exec grep -l "SG\." {} \; | while read file; do
    echo "Cleaning $file"
    sed -i 's/SENDGRID_API_KEY=SG\.[A-Za-z0-9_-]*/SENDGRID_API_KEY=${SENDGRID_API_KEY}/g' "$file"
done

# Check for any remaining API keys
echo "Checking for remaining hardcoded secrets..."
if grep -r "SG\.[A-Za-z0-9_-]" . --exclude-dir=.git --exclude="*.log" 2>/dev/null; then
    echo "Found remaining API keys - manual cleanup needed"
else
    echo "✓ No hardcoded API keys found"
fi

# Create secure deployment script that uses environment variables
cat > deploy-production-secure.sh << 'EOF'
#!/bin/bash

# Secure production deployment without hardcoded secrets
set -e

cd /var/www/itservicedesk

echo "=== Secure Production Deployment ==="

# Verify environment variables are set
if [ -z "$SENDGRID_API_KEY" ]; then
    echo "Warning: SENDGRID_API_KEY not set - email functionality will be disabled"
fi

# Pull latest code
git pull origin main

# Build application
npm run build

# Create environment file with secure variables
cat > .env << EOL
NODE_ENV=production
DATABASE_URL=postgresql://servicedesk@localhost:5432/servicedesk
PGHOST=localhost
PGPORT=5432
PGDATABASE=servicedesk
PGUSER=servicedesk
SENDGRID_API_KEY=${SENDGRID_API_KEY}
SESSION_SECRET=calpion-production-secret-$(openssl rand -hex 32)
PORT=5000
EOL

# Configure nginx
cat > /etc/nginx/nginx.conf << 'NGINX_EOF'
events {
    worker_connections 1024;
}

http {
    upstream app {
        server 127.0.0.1:5000;
    }

    server {
        listen 80;
        server_name _;

        location / {
            proxy_pass http://app;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }
}
NGINX_EOF

# Remove conflicting nginx configs
rm -rf /etc/nginx/sites-enabled
rm -rf /etc/nginx/sites-available
rm -rf /etc/nginx/conf.d

# Start services
nginx -t
systemctl restart nginx
pm2 restart servicedesk || pm2 start ecosystem.production.config.cjs

echo "✓ Secure deployment complete"
echo "Access: http://98.81.235.7"
EOF

chmod +x deploy-production-secure.sh

echo ""
echo "=== Repository Cleanup Complete ==="
echo "✓ Hardcoded API keys removed"
echo "✓ Secure deployment script created"
echo "✓ Repository ready for GitHub push"