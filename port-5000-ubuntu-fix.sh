#!/bin/bash

echo "Switching Ubuntu Server to Port 5000 - Complete Fix"
echo "=================================================="

cat << 'EOF'
# Run on Ubuntu server 98.81.235.7 to use port 5000 everywhere:

cd /var/www/itservicedesk

# Stop all processes
pm2 delete all 2>/dev/null || true
sudo fuser -k 3000/tcp 2>/dev/null || true
sudo fuser -k 5000/tcp 2>/dev/null || true

# Update Nginx to proxy to port 5000
sudo tee /etc/nginx/sites-available/servicedesk << 'NGINX_EOF'
server {
    listen 80;
    server_name 98.81.235.7;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name 98.81.235.7;

    ssl_certificate /etc/nginx/ssl/servicedesk.crt;
    ssl_certificate_key /etc/nginx/ssl/servicedesk.key;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;
    
    add_header Strict-Transport-Security "max-age=63072000" always;

    location / {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
NGINX_EOF

# Test and reload Nginx
sudo nginx -t
sudo systemctl reload nginx

# Create PM2 config for port 5000
cat > port5000.config.cjs << 'PM2_EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'dist/index.js',
    cwd: '/var/www/itservicedesk',
    instances: 1,
    autorestart: true,
    env: {
      NODE_ENV: 'production',
      PORT: 5000,
      DATABASE_URL: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk'
    }
  }]
};
PM2_EOF

# Build and start application
npm run build
pm2 start port5000.config.cjs
pm2 save

# Wait and test
sleep 15

echo "Testing on port 5000..."
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.user","password":"password123"}'

echo ""
echo "Testing external HTTPS access..."
curl -k https://98.81.235.7/api/auth/me

echo ""
echo "Application status:"
pm2 status

EOF

echo ""
echo "This will:"
echo "- Change application to use port 5000"
echo "- Update Nginx to proxy from 443/80 to port 5000"
echo "- Eliminate all port conflicts"
echo "- Make development and production consistent"