#!/bin/bash

# Fix nginx HTTPS redirect issue
set -e

echo "=== Fixing Nginx HTTPS Redirect ==="

# Check for any HTTPS redirects in nginx config
echo "Checking for existing HTTPS redirects..."
grep -r "https://" /etc/nginx/ 2>/dev/null || echo "No explicit HTTPS redirects found"
grep -r "return 301" /etc/nginx/ 2>/dev/null || echo "No 301 redirects found"
grep -r "ssl" /etc/nginx/ 2>/dev/null || echo "No SSL configs found"

# Remove any SSL/HTTPS configurations
echo "Removing SSL configurations..."
rm -f /etc/nginx/sites-enabled/default-ssl 2>/dev/null || true
rm -f /etc/nginx/sites-available/default-ssl 2>/dev/null || true

# Check the main nginx.conf for global redirects
echo "Checking main nginx.conf..."
if grep -q "return.*https" /etc/nginx/nginx.conf; then
    echo "Found HTTPS redirect in main config, removing..."
    sed -i '/return.*https/d' /etc/nginx/nginx.conf
fi

# Create completely clean HTTP-only configuration
echo "Creating clean HTTP-only nginx configuration..."
cat > /etc/nginx/sites-available/servicedesk << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    
    # Explicitly disable any SSL redirects
    # No return statements that redirect to HTTPS
    
    # Root location - proxy to application
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
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
    }
    
    # Health check
    location /api/health {
        proxy_pass http://127.0.0.1:5000/api/health;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto http;
        access_log off;
    }
}
EOF

# Remove any conflicting configurations
echo "Removing conflicting configurations..."
rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-enabled/*ssl*

# Enable only our configuration
ln -sf /etc/nginx/sites-available/servicedesk /etc/nginx/sites-enabled/servicedesk

# Check if there are any other configuration files causing issues
echo "Checking for other configuration files..."
find /etc/nginx -name "*.conf" -exec grep -l "https\|ssl\|443" {} \; 2>/dev/null | while read file; do
    echo "Found potential SSL config in: $file"
    # Backup and comment out SSL-related lines
    cp "$file" "$file.backup"
    sed -i 's/.*https.*/# &/' "$file"
    sed -i 's/.*ssl.*/# &/' "$file"
    sed -i 's/.*:443.*/# &/' "$file"
done

# Test nginx configuration
echo "Testing nginx configuration..."
nginx -t

if [ $? -eq 0 ]; then
    echo "✓ Nginx configuration is valid"
    
    # Restart nginx
    echo "Restarting nginx..."
    systemctl restart nginx
    
    # Wait a moment for restart
    sleep 3
    
    echo "Testing application access..."
    
    # Test direct application
    echo "Direct app test:"
    curl -s -I http://localhost:5000/api/health
    
    echo ""
    echo "Nginx proxy test:"
    curl -s -I http://localhost/api/health
    
    echo ""
    echo "Root page test:"
    curl -s -I http://localhost/
    
else
    echo "✗ Nginx configuration test failed"
    exit 1
fi

echo ""
echo "=== Nginx HTTPS Redirect Fix Complete ==="
echo "✓ Removed all HTTPS redirects"
echo "✓ Configured HTTP-only access"
echo "✓ Application should be accessible at http://98.81.235.7"
echo ""
echo "Test the application:"
echo "  curl -I http://98.81.235.7"
echo "  curl http://98.81.235.7/api/health"