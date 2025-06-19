#!/bin/bash

# Fix connection reset error - comprehensive networking fix
set -e

echo "=== Fixing Connection Reset Error ==="

echo "1. Installing required networking tools..."
apt-get update -qq
apt-get install -y net-tools ufw curl

echo "2. Checking current firewall status..."
ufw status

echo "3. Ensuring HTTP port 80 is open..."
ufw allow 80/tcp
ufw allow 'Nginx HTTP'

echo "4. Checking if nginx is running and listening on port 80..."
systemctl status nginx --no-pager
netstat -tlnp | grep :80

echo "5. Checking Node.js application on port 3000..."
systemctl status itservicedesk --no-pager
netstat -tlnp | grep :3000 || echo "Port 3000 not listening"

echo "6. Testing local connections..."
echo "Testing localhost:3000..."
curl -I http://localhost:3000 || echo "Cannot connect to localhost:3000"

echo "Testing localhost:80..."
curl -I http://localhost:80 || echo "Cannot connect to localhost:80"

echo "7. Updating nginx configuration with better error handling..."
cat > /etc/nginx/sites-available/itservicedesk << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name 98.81.235.7 _ default;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;

    # Main application proxy
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        
        # Increased timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Buffer settings
        proxy_buffering on;
        proxy_buffer_size 128k;
        proxy_buffers 4 256k;
        proxy_busy_buffers_size 256k;
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

echo "8. Removing default nginx site that might conflict..."
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/itservicedesk /etc/nginx/sites-enabled/

echo "9. Testing nginx configuration..."
nginx -t

echo "10. Checking if Node.js app needs to bind to all interfaces..."
echo "Checking current server binding in server-production.cjs..."
grep -n "listen\|port" server-production.cjs || echo "Cannot find listen configuration"

echo "11. Updating server to bind to all interfaces (0.0.0.0)..."
# Backup current server file
cp server-production.cjs server-production.cjs.backup

# Update server to bind to 0.0.0.0 instead of localhost
sed -i 's/localhost/0.0.0.0/g' server-production.cjs
sed -i 's/127.0.0.1/0.0.0.0/g' server-production.cjs

echo "12. Restarting services..."
systemctl restart itservicedesk
sleep 3
systemctl restart nginx

echo "13. Final verification..."
echo "Node.js service status:"
systemctl status itservicedesk --no-pager

echo "Nginx service status:"
systemctl status nginx --no-pager

echo "Port 3000 listening:"
netstat -tlnp | grep :3000

echo "Port 80 listening:"
netstat -tlnp | grep :80

echo "Testing connections:"
curl -I http://localhost:3000 || echo "Cannot connect to localhost:3000"
curl -I http://localhost:80 || echo "Cannot connect to localhost:80"

echo ""
echo "=== Fix Complete ==="
echo "✓ Firewall configured for HTTP access"
echo "✓ Nginx configured with better proxy settings"
echo "✓ Node.js server configured to bind to all interfaces"
echo "✓ Services restarted"
echo ""
echo "Your IT Service Desk should now be accessible at: http://98.81.235.7"
echo ""
echo "If still having issues, check the logs:"
echo "sudo journalctl -u itservicedesk -f"
echo "sudo tail -f /var/log/nginx/error.log"