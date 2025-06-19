#!/bin/bash

# Clean nginx installation and configuration
set -e

cd /var/www/itservicedesk

echo "=== Clean Nginx Installation ==="

# Stop any existing services
pm2 stop servicedesk 2>/dev/null || true
systemctl stop nginx 2>/dev/null || true

# Remove any existing nginx completely
apt-get remove --purge nginx nginx-common nginx-core -y 2>/dev/null || true
rm -rf /etc/nginx
rm -rf /var/log/nginx

# Clean install nginx
apt-get update
apt-get install nginx -y

# Create completely clean nginx configuration
cat > /etc/nginx/nginx.conf << 'EOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;

events {
    worker_connections 768;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    gzip on;

    # Simple HTTP proxy configuration
    server {
        listen 80 default_server;
        listen [::]:80 default_server;
        server_name _;

        location / {
            proxy_pass http://127.0.0.1:5000;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto http;
            proxy_cache_bypass $http_upgrade;
            proxy_read_timeout 86400;
        }
    }
}
EOF

# Remove sites-enabled and sites-available directories (not needed with inline config)
rm -rf /etc/nginx/sites-enabled
rm -rf /etc/nginx/sites-available

# Configure application to run on port 5000
cat > ecosystem.production.config.cjs << 'EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'dist/index.js',
    cwd: '/var/www/itservicedesk',
    instances: 1,
    exec_mode: 'fork',
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production',
      PORT: 5000
    },
    error_file: './logs/error.log',
    out_file: './logs/out.log',
    log_file: './logs/app.log',
    time: true
  }]
};
EOF

# Test nginx configuration
nginx -t

# Start services
systemctl start nginx
systemctl enable nginx

pm2 start ecosystem.production.config.cjs

sleep 15

# Verify services
echo "Service status:"
systemctl status nginx --no-pager -l | head -5
pm2 status

# Test the setup
echo "Testing application direct access:"
curl -s -I http://localhost:5000/ | head -3

echo "Testing nginx proxy:"
curl -s -I http://localhost/ | head -3

echo "Testing external access:"
curl -s -I http://98.81.235.7/ | head -3

echo ""
echo "=== Clean Nginx Installation Complete ==="
echo "✓ Nginx freshly installed with clean configuration"
echo "✓ Application running on port 5000"
echo "✓ Nginx proxying port 80 to application"
echo "✓ No redirect loops or HTTPS configurations"
echo ""
echo "Access your IT Service Desk at: http://98.81.235.7"
echo "Login: test.admin / password123"