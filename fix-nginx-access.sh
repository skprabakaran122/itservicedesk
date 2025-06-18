#!/bin/bash

echo "=== FIXING NGINX AND FIREWALL ACCESS ==="

APP_DIR="/var/www/itservicedesk"
SERVICE_NAME="itservicedesk"

# Check current status
echo "Checking current service status..."
sudo systemctl status $SERVICE_NAME --no-pager --lines=5

echo "Checking if application is running locally..."
LOCAL_TEST=$(curl -s http://localhost:5000/health 2>/dev/null)
if echo "$LOCAL_TEST" | grep -q '"status":"OK"'; then
    echo "✓ Application running locally on port 5000"
else
    echo "✗ Application not responding locally"
    
    # Check what's using port 5000
    echo "Checking port 5000 usage..."
    sudo lsof -i :5000 || echo "Port 5000 is free"
    
    # Restart the service
    echo "Restarting application service..."
    sudo systemctl restart $SERVICE_NAME
    sleep 10
    
    # Test again
    LOCAL_TEST=$(curl -s http://localhost:5000/health 2>/dev/null)
    if echo "$LOCAL_TEST" | grep -q '"status":"OK"'; then
        echo "✓ Application now running after restart"
    else
        echo "✗ Application still not responding"
        sudo journalctl -u $SERVICE_NAME --no-pager --lines=20
        exit 1
    fi
fi

# Configure nginx to proxy to the application
echo "Configuring nginx reverse proxy..."
sudo tee /etc/nginx/sites-available/default > /dev/null << 'NGINX_EOF'
server {
    listen 80;
    server_name 98.81.235.7;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name 98.81.235.7;

    # SSL Configuration
    ssl_certificate /var/www/itservicedesk/ssl/server.crt;
    ssl_certificate_key /var/www/itservicedesk/ssl/server.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Proxy to Node.js application
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
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Handle API routes specifically
    location /api/ {
        proxy_pass http://127.0.0.1:5000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }

    # Health check endpoint
    location /health {
        proxy_pass http://127.0.0.1:5000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        access_log off;
    }
}
NGINX_EOF

# Ensure SSL certificates exist
echo "Checking SSL certificates..."
if [ ! -f "/var/www/itservicedesk/ssl/server.crt" ]; then
    echo "Creating SSL certificates..."
    sudo mkdir -p /var/www/itservicedesk/ssl
    cd /var/www/itservicedesk/ssl
    
    # Create self-signed certificate
    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout server.key -out server.crt \
        -subj "/C=US/ST=State/L=City/O=Calpion/CN=98.81.235.7"
    
    sudo chown -R ubuntu:ubuntu /var/www/itservicedesk/ssl
    echo "✓ SSL certificates created"
else
    echo "✓ SSL certificates already exist"
fi

# Test nginx configuration
echo "Testing nginx configuration..."
sudo nginx -t
if [ $? -eq 0 ]; then
    echo "✓ Nginx configuration valid"
else
    echo "✗ Nginx configuration error"
    exit 1
fi

# Restart nginx
echo "Restarting nginx..."
sudo systemctl restart nginx
sudo systemctl enable nginx

# Check firewall settings
echo "Checking firewall settings..."
sudo ufw status
echo "Ensuring required ports are open..."
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable

echo "Checking nginx status..."
sudo systemctl status nginx --no-pager --lines=5

# Test local HTTPS access
echo "Testing local HTTPS access..."
HTTPS_LOCAL_TEST=$(curl -k -s https://localhost/health 2>/dev/null)
if echo "$HTTPS_LOCAL_TEST" | grep -q '"status":"OK"'; then
    echo "✓ HTTPS working locally through nginx"
else
    echo "✗ HTTPS not working locally"
    echo "Testing direct nginx connection..."
    curl -k -v https://localhost/ 2>&1 | head -10
fi

# Test external access
echo "Testing external access..."
EXTERNAL_TEST=$(curl -k -s --connect-timeout 10 https://98.81.235.7/health 2>/dev/null)
if echo "$EXTERNAL_TEST" | grep -q '"status":"OK"'; then
    echo "✓ External HTTPS access working"
else
    echo "✗ External access failed, checking network connectivity..."
    
    # Check if nginx is listening on correct ports
    echo "Checking nginx listening ports..."
    sudo netstat -tlnp | grep nginx
    
    # Check if we can reach the server from itself
    echo "Testing server self-access..."
    curl -k -s --connect-timeout 5 https://98.81.235.7/health 2>&1 || echo "Self-access failed"
fi

# Show current processes and ports
echo "Current service status:"
echo "Application service:"
sudo systemctl is-active $SERVICE_NAME
echo "Nginx service:"
sudo systemctl is-active nginx
echo "Ports in use:"
sudo netstat -tlnp | grep -E ':(80|443|5000)'

# Test authentication flow
echo "Testing authentication..."
LOGIN_TEST=$(curl -k -s -X POST https://98.81.235.7/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"username":"john.doe","password":"password123"}' 2>/dev/null)

if echo "$LOGIN_TEST" | grep -q '"username":"john.doe"'; then
    echo "✓ Authentication working through HTTPS"
else
    echo "✗ Authentication test failed"
    echo "Response: $LOGIN_TEST"
fi

echo ""
echo "=== ACCESS CONFIGURATION COMPLETE ==="
echo ""
echo "External access: https://98.81.235.7"
echo "Login: john.doe / password123"
echo ""
echo "If external access still fails:"
echo "1. Check your network firewall/security groups"
echo "2. Verify port 443 is open to your IP address"
echo "3. Check if your ISP blocks port 443"