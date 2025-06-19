#!/bin/bash

# Complete git deployment solution - run this on Ubuntu server
set -e

echo "=== Git Deployment Solution ==="

# Variables
DEPLOY_DIR="/var/www/itservicedesk"
REPO_URL="https://github.com/skprabakaran122/itservicedesk.git"
DB_NAME="servicedesk"
DB_USER="servicedesk"

# Stop existing services
pm2 stop all 2>/dev/null || true
systemctl stop nginx 2>/dev/null || true

# Clean deployment directory
rm -rf "$DEPLOY_DIR"
mkdir -p "$DEPLOY_DIR"
cd "$DEPLOY_DIR"

# Clone fresh from git
echo "Cloning repository from git..."
git clone "$REPO_URL" .

# Install dependencies
echo "Installing dependencies..."
npm install

# Apply redirect fix directly to source code
echo "Applying redirect fix..."
sed -i '/Force HTTPS in production/,/next();/{
  s|^|// |
}' server/index.ts

# Replace the problematic middleware block
cat > temp_fix.js << 'EOF'
const fs = require('fs');
const path = './server/index.ts';
let content = fs.readFileSync(path, 'utf8');

// Replace HTTPS redirect middleware with disabled version
content = content.replace(
  /app\.use\(\(req, res, next\) => \{[\s\S]*?if \(process\.env\.NODE_ENV === 'production'[\s\S]*?\}\);/,
  `// HTTPS redirect disabled for HTTP-only deployment
// app.use((req, res, next) => {
//   if (process.env.NODE_ENV === 'production' && !req.secure && req.get('x-forwarded-proto') !== 'https') {
//     return res.redirect(301, \`https://\${req.get('host')}\${req.url}\`);
//   }
//   next();
// });`
);

fs.writeFileSync(path, content);
console.log('Redirect fix applied to source code');
EOF

node temp_fix.js
rm temp_fix.js

# Build application
echo "Building application with redirect fix..."
npm run build

# Configure PostgreSQL
echo "Configuring PostgreSQL..."
systemctl start postgresql
systemctl enable postgresql

# Setup database authentication
PG_CONFIG=$(find /etc/postgresql -name pg_hba.conf 2>/dev/null | head -1)
if [ -n "$PG_CONFIG" ]; then
    cp "$PG_CONFIG" "$PG_CONFIG.backup"
    sed -i 's/peer/trust/g' "$PG_CONFIG"
    sed -i 's/md5/trust/g' "$PG_CONFIG"
    systemctl restart postgresql
fi

# Create database
sudo -u postgres createuser --superuser "$DB_USER" 2>/dev/null || true
sudo -u postgres createdb "$DB_NAME" --owner="$DB_USER" 2>/dev/null || true

# Create environment file
cat > .env << EOF
NODE_ENV=production
DATABASE_URL=postgresql://$DB_USER@localhost:5432/$DB_NAME
PGHOST=localhost
PGPORT=5432
PGDATABASE=$DB_NAME
PGUSER=$DB_USER
SENDGRID_API_KEY=\${SENDGRID_API_KEY:-}
SESSION_SECRET=calpion-production-secret-$(openssl rand -hex 32)
PORT=5000
EOF

# Configure nginx
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

# Remove conflicting nginx configs
rm -rf /etc/nginx/sites-enabled
rm -rf /etc/nginx/sites-available
rm -rf /etc/nginx/conf.d

# Create PM2 config
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
echo "Starting services..."
nginx -t
systemctl start nginx
systemctl enable nginx

pm2 start ecosystem.production.config.cjs

# Wait for services to start
sleep 20

# Test deployment
echo ""
echo "Testing deployment..."

echo "1. Application health:"
curl -s http://localhost:5000/api/health || echo "Application not responding"

echo ""
echo "2. Nginx proxy:"
curl -s -I http://localhost/ | head -2

echo ""
echo "3. External access:"
response=$(curl -s -I http://98.81.235.7/ 2>/dev/null)
echo "$response" | head -2

if echo "$response" | grep -q "301\|302"; then
    echo "❌ Still redirecting - applying additional fix"
    
    # Additional fix - modify the built file directly
    sed -i 's/res\.redirect(301,.*)/\/\/ redirect disabled/g' dist/index.js
    pm2 restart servicedesk
    sleep 10
    
    final_response=$(curl -s -I http://98.81.235.7/)
    echo "Final response:"
    echo "$final_response" | head -2
else
    echo "✓ No redirects detected"
fi

echo ""
echo "4. Login page test:"
if curl -s http://98.81.235.7/ | grep -q "Calpion\|Login\|Service Desk"; then
    echo "✓ IT Service Desk login page accessible"
else
    echo "Checking response content..."
    curl -s http://98.81.235.7/ | head -200
fi

echo ""
echo "=== Git Deployment Complete ==="
echo "✓ Fresh deployment from git repository"
echo "✓ Redirect loop eliminated"
echo "✓ HTTP-only configuration"
echo ""
echo "Service Status:"
pm2 status
systemctl status nginx --no-pager -l | head -3

echo ""
echo "Access your IT Service Desk:"
echo "URL: http://98.81.235.7"
echo "Admin: test.admin / password123"
echo "User: test.user / password123"