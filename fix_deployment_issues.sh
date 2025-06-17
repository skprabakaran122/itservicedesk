#!/bin/bash

# Fix deployment issues
echo "Fixing deployment issues..."

cd /var/www/servicedesk

# 1. Fix PM2 ecosystem config (change to .cjs extension for CommonJS)
echo "1. Fixing PM2 configuration..."
cat > ecosystem.config.cjs << 'EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'tsx',
    args: 'server/index.ts',
    cwd: '/var/www/servicedesk',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    error_file: '/var/log/servicedesk/error.log',
    out_file: '/var/log/servicedesk/out.log',
    log_file: '/var/log/servicedesk/combined.log',
    time: true
  }]
};
EOF

# 2. Fix Nginx configuration
echo "2. Fixing Nginx configuration..."
SERVER_DOMAIN=$(hostname -I | awk '{print $1}')

sudo tee /etc/nginx/sites-available/servicedesk << EOF
server {
    listen 80;
    server_name $SERVER_DOMAIN;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # Security headers
        add_header X-Frame-Options DENY;
        add_header X-Content-Type-Options nosniff;
        add_header X-XSS-Protection "1; mode=block";
    }

    # Serve static files
    location /static/ {
        alias /var/www/servicedesk/dist/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    client_max_body_size 10M;
}
EOF

# Test and restart Nginx
sudo nginx -t
if [ $? -eq 0 ]; then
    sudo systemctl restart nginx
    echo "✓ Nginx configuration fixed"
else
    echo "✗ Nginx configuration still has issues"
    sudo nginx -t
fi

# 3. Start PM2 with correct config
echo "3. Starting PM2 application..."
pm2 delete servicedesk 2>/dev/null || true
pm2 start ecosystem.config.cjs
pm2 save

# 4. Check application status
echo "4. Checking application status..."
sleep 5

# Test database
if pg_isready -h localhost -p 5432 -U servicedesk; then
    echo "✓ Database connection successful"
else
    echo "✗ Database connection failed"
fi

# Test application
if curl -s http://localhost:3000 > /dev/null; then
    echo "✓ Application responding on port 3000"
else
    echo "✗ Application not responding on port 3000"
    echo "Checking PM2 logs..."
    pm2 logs servicedesk --lines 10
fi

# Test Nginx
if sudo nginx -t 2>/dev/null; then
    echo "✓ Nginx configuration valid"
else
    echo "✗ Nginx configuration invalid"
    sudo nginx -t
fi

echo ""
echo "Status check complete. Your application should be available at:"
echo "http://$SERVER_DOMAIN"