#!/bin/bash

# Final Ubuntu deployment script without hardcoded secrets
set -e

cd /var/www/itservicedesk

echo "=== Final Ubuntu Deployment ==="

# Pull latest code with redirect fix
git pull origin main

# Build application
npm run build

# Create environment file using environment variables
cat > .env << EOF
NODE_ENV=production
DATABASE_URL=postgresql://servicedesk@localhost:5432/servicedesk
PGHOST=localhost
PGPORT=5432
PGDATABASE=servicedesk
PGUSER=servicedesk
SENDGRID_API_KEY=\${SENDGRID_API_KEY}
SESSION_SECRET=calpion-production-secret-\$(openssl rand -hex 32)
PORT=5000
EOF

# Configure nginx with simple proxy
cat > /etc/nginx/nginx.conf << 'EOF'
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
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
        }
    }
}
EOF

# Remove conflicting configurations
rm -rf /etc/nginx/sites-enabled
rm -rf /etc/nginx/sites-available
rm -rf /etc/nginx/conf.d

# Test and restart services
nginx -t
systemctl restart nginx

pm2 stop servicedesk 2>/dev/null || true
pm2 start ecosystem.production.config.cjs

sleep 15

# Test deployment
echo "Testing deployment..."
curl -s -I http://localhost:5000/api/health
curl -s -I http://98.81.235.7/

echo "Deployment complete - Access: http://98.81.235.7"