#!/bin/bash

echo "=== COMPLETE ACCESS CONFIGURATION ==="

# Check if the application is running
echo "Verifying application status..."
if ! curl -s http://localhost:5000/health >/dev/null; then
    echo "Application not running, starting it..."
    cd /var/www/itservicedesk
    sudo systemctl restart itservicedesk
    sleep 15
fi

# Install nginx if not present
if ! command -v nginx &> /dev/null; then
    echo "Installing nginx..."
    sudo apt update
    sudo apt install -y nginx
fi

# Stop nginx to avoid conflicts during configuration
sudo systemctl stop nginx

# Create SSL certificates
echo "Setting up SSL certificates..."
sudo mkdir -p /var/www/itservicedesk/ssl
cd /var/www/itservicedesk/ssl

if [ ! -f "server.crt" ]; then
    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout server.key -out server.crt \
        -subj "/C=US/ST=CA/L=San Francisco/O=Calpion/CN=98.81.235.7" \
        -addext "subjectAltName=IP:98.81.235.7"
fi

sudo chown -R ubuntu:ubuntu /var/www/itservicedesk/ssl

# Configure nginx with proper reverse proxy
echo "Configuring nginx reverse proxy..."
sudo tee /etc/nginx/sites-available/default > /dev/null << 'NGINX_CONFIG'
# HTTP to HTTPS redirect
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    return 301 https://$host$request_uri;
}

# HTTPS server
server {
    listen 443 ssl http2 default_server;
    listen [::]:443 ssl http2 default_server;
    server_name _;

    # SSL Configuration
    ssl_certificate /var/www/itservicedesk/ssl/server.crt;
    ssl_certificate_key /var/www/itservicedesk/ssl/server.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Security headers
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Proxy all requests to Node.js application
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
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Buffer settings
        proxy_buffering on;
        proxy_buffer_size 128k;
        proxy_buffers 4 256k;
        proxy_busy_buffers_size 256k;
    }

    # Specific handling for API routes
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

    # Health check with no logging
    location /health {
        proxy_pass http://127.0.0.1:5000;
        access_log off;
    }
}
NGINX_CONFIG

# Test nginx configuration
echo "Testing nginx configuration..."
if ! sudo nginx -t; then
    echo "Nginx configuration error"
    exit 1
fi

# Configure firewall properly
echo "Configuring firewall..."
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable

# Start services
echo "Starting services..."
sudo systemctl enable nginx
sudo systemctl start nginx
sudo systemctl enable itservicedesk
sudo systemctl restart itservicedesk

# Wait for services to start
sleep 10

# Verify services are running
echo "Verifying services..."
if systemctl is-active --quiet nginx; then
    echo "✓ Nginx is running"
else
    echo "✗ Nginx failed to start"
    sudo systemctl status nginx --no-pager
fi

if systemctl is-active --quiet itservicedesk; then
    echo "✓ Application service is running"
else
    echo "✗ Application service failed"
    sudo systemctl status itservicedesk --no-pager
fi

# Test local connectivity
echo "Testing local connectivity..."
if curl -s http://localhost:5000/health | grep -q "OK"; then
    echo "✓ Application responding on port 5000"
else
    echo "✗ Application not responding on port 5000"
fi

if curl -k -s https://localhost/health | grep -q "OK"; then
    echo "✓ HTTPS proxy working"
else
    echo "✗ HTTPS proxy not working"
fi

# Check listening ports
echo "Checking listening ports..."
sudo netstat -tlnp | grep -E ':(80|443|5000)' | while read line; do
    echo "  $line"
done

# Test authentication
echo "Testing authentication flow..."
AUTH_TEST=$(curl -k -s -X POST https://localhost/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"username":"john.doe","password":"password123"}')

if echo "$AUTH_TEST" | grep -q "john.doe"; then
    echo "✓ Authentication working"
else
    echo "✗ Authentication failed"
fi

# Final external test
echo "Testing external access..."
EXTERNAL_TEST=$(timeout 10 curl -k -s https://98.81.235.7/health 2>/dev/null || echo "TIMEOUT")

if echo "$EXTERNAL_TEST" | grep -q "OK"; then
    echo "✓ External access working"
elif echo "$EXTERNAL_TEST" | grep -q "TIMEOUT"; then
    echo "✗ External access timeout - check network/firewall"
else
    echo "✗ External access failed"
fi

echo ""
echo "=== CONFIGURATION COMPLETE ==="
echo "Access URL: https://98.81.235.7"
echo "Login: john.doe / password123"
echo ""
echo "If still getting connection refused:"
echo "1. Check AWS/Cloud security groups allow port 443"
echo "2. Verify your IP isn't blocked by provider firewall"
echo "3. Try accessing from different network/device"