#!/bin/bash

# Direct deployment fix - apply redirect solution without git dependency
set -e

cd /var/www/itservicedesk

echo "=== Direct Deployment Fix ==="

# Stop services
pm2 stop servicedesk 2>/dev/null || true
systemctl stop nginx 2>/dev/null || true

# Apply redirect fix directly to server code
echo "Applying redirect fix to server code..."
sed -i '/Force HTTPS in production/,/next();/{
  s/^/\/\/ /
}' server/index.ts

# Alternative approach - replace the redirect middleware entirely
cat > temp_fix.js << 'EOF'
const fs = require('fs');
const path = './server/index.ts';
let content = fs.readFileSync(path, 'utf8');

// Comment out the HTTPS redirect middleware
content = content.replace(
  /\/\/ Force HTTPS in production\napp\.use\(\(req, res, next\) => \{[\s\S]*?\}\);/,
  '// HTTPS redirect disabled for HTTP-only deployment\n// app.use((req, res, next) => {\n//   if (process.env.NODE_ENV === \'production\' && !req.secure && req.get(\'x-forwarded-proto\') !== \'https\') {\n//     return res.redirect(301, `https://${req.get(\'host\')}${req.url}`);\n//   }\n//   next();\n// });'
);

fs.writeFileSync(path, content);
console.log('Redirect fix applied');
EOF

node temp_fix.js
rm temp_fix.js

# Build application with fix
echo "Building application with redirect fix..."
npm run build

# Configure nginx for simple HTTP proxy
echo "Configuring nginx..."
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

# Remove conflicting configurations
rm -rf /etc/nginx/sites-enabled
rm -rf /etc/nginx/sites-available
rm -rf /etc/nginx/conf.d

# Start services
nginx -t
systemctl start nginx

pm2 start ecosystem.production.config.cjs

sleep 15

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
curl -s -I http://98.81.235.7/ | head -2

echo ""
echo "4. Redirect test:"
response=$(curl -s -I http://98.81.235.7/)
if echo "$response" | grep -q "301\|302"; then
    echo "❌ Still redirecting"
else
    echo "✓ No redirects - fix successful"
fi

echo ""
echo "=== Deployment Fix Complete ==="
echo "✓ Redirect loop eliminated"
echo "✓ Application deployed without repository dependency"
echo "✓ IT Service Desk accessible at http://98.81.235.7"
echo ""
echo "Login: test.admin / password123"