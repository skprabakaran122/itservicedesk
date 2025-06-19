#!/bin/bash

# Simple nginx setup without any redirects
set -e

cd /var/www/itservicedesk

echo "=== Simple Nginx Setup ==="

# Clean slate approach
systemctl stop nginx 2>/dev/null || true
pm2 stop servicedesk 2>/dev/null || true

# Remove existing nginx and reinstall
apt-get remove --purge nginx* -y 2>/dev/null || true
apt-get autoremove -y
apt-get update
apt-get install nginx -y

# Create the simplest possible nginx configuration
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
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }
}
EOF

# Remove all unnecessary directories
rm -rf /etc/nginx/sites-*
rm -rf /etc/nginx/conf.d

# Ensure application runs on port 5000
cat > ecosystem.config.cjs << 'EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'dist/index.js',
    env: {
      NODE_ENV: 'production',
      PORT: 5000
    }
  }]
};
EOF

# Start services
nginx -t
systemctl start nginx

pm2 start ecosystem.config.cjs
sleep 10

# Verify everything works
echo "Testing setup:"
curl -s -I http://localhost:5000/api/health | head -2
curl -s -I http://localhost/ | head -2

pm2 status

echo ""
echo "✓ Simple nginx setup complete"
echo "✓ Application: port 5000"
echo "✓ Nginx: port 80 → 5000"
echo "Access: http://98.81.235.7"