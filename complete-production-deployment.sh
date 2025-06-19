#!/bin/bash

# Complete production deployment with nginx proxy fix
set -e

cd /var/www/itservicedesk

echo "=== Complete Production Deployment ==="

# Ensure application is built and running
echo "Building application..."
npm run build

# Stop services
systemctl stop nginx 2>/dev/null || true
pm2 stop servicedesk 2>/dev/null || true

# Configure nginx with proper proxy
cat > /etc/nginx/nginx.conf << 'EOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

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

    ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    gzip on;

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
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_cache_bypass $http_upgrade;
            proxy_read_timeout 86400;
            proxy_connect_timeout 60s;
            proxy_send_timeout 60s;
        }
    }
}
EOF

# Remove any conflicting configurations
rm -rf /etc/nginx/sites-enabled
rm -rf /etc/nginx/sites-available
rm -rf /etc/nginx/conf.d

# Test nginx configuration
nginx -t

# Start PM2 with production configuration
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

# Create logs directory
mkdir -p logs

# Start services
pm2 start ecosystem.production.config.cjs
sleep 15

systemctl start nginx
systemctl enable nginx

sleep 10

# Verify deployment
echo ""
echo "=== Verifying Deployment ==="

echo "PM2 Status:"
pm2 status

echo ""
echo "Application Health Check:"
curl -s http://localhost:5000/api/health || echo "Application not responding"

echo ""
echo "Nginx Proxy Test:"
if curl -s http://localhost/ | grep -q "Calpion\|Service Desk\|Login"; then
    echo "✓ Nginx proxy working - IT Service Desk accessible"
elif curl -s http://localhost/ | grep -q "Welcome to nginx"; then
    echo "❌ Still showing nginx default page"
else
    echo "Testing response..."
    curl -s -I http://localhost/ | head -3
fi

echo ""
echo "External Access Test:"
curl -s -I http://98.81.235.7/ | head -3

echo ""
echo "=== Deployment Complete ==="
echo "IT Service Desk URL: http://98.81.235.7"
echo "Admin Login: test.admin / password123"
echo "User Login: test.user / password123"
echo ""
echo "To verify full deployment, run: bash verify-application.sh"