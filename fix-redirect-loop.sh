#!/bin/bash

# Fix nginx redirect loop issue
set -e

echo "=== Fixing Nginx Redirect Loop ==="

# Check current nginx configuration
echo "Current nginx configuration:"
cat /etc/nginx/sites-available/servicedesk

echo ""
echo "Creating corrected nginx configuration..."

# Create simple HTTP-only configuration without redirects
cat > /etc/nginx/sites-available/servicedesk << 'EOF'
server {
    listen 80;
    server_name _;

    # Remove any redirect directives
    
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
        proxy_read_timeout 86400;
        
        # Add error handling
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
    }
    
    # Health check endpoint
    location /api/health {
        proxy_pass http://localhost:5000/api/health;
        access_log off;
    }
}
EOF

echo "Testing nginx configuration..."
nginx -t

if [ $? -eq 0 ]; then
    echo "✓ Nginx configuration valid"
    
    echo "Restarting nginx..."
    systemctl restart nginx
    
    echo "Checking nginx status..."
    systemctl status nginx --no-pager -l
    
    echo "Testing direct connection to app..."
    curl -s -I http://localhost:5000/api/health
    
    echo ""
    echo "Testing through nginx..."
    curl -s -I http://localhost/api/health
    
    echo ""
    echo "Testing main page..."
    curl -s -I http://localhost/
    
else
    echo "✗ Nginx configuration test failed"
    exit 1
fi

echo ""
echo "=== Redirect Loop Fix Complete ==="
echo "✓ Removed HTTPS redirects"
echo "✓ Configured HTTP-only access"
echo "✓ Application should now be accessible at http://98.81.235.7"
echo ""
echo "Test the application:"
echo "  curl -I http://98.81.235.7"
echo "  curl http://98.81.235.7/api/health"