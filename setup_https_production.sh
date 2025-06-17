#!/bin/bash

# Setup HTTPS for production server

echo "=== Setting up HTTPS for Production Server ==="

cd /var/www/servicedesk

# Stop current service
sudo systemctl stop servicedesk.service

echo "1. Installing SSL certificate tools..."
sudo apt update
sudo apt install -y certbot nginx

echo "2. Detecting server setup..."
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s api.ipify.org)
echo "Server IP: $SERVER_IP"

# Check if domain name is configured
if [ -n "$1" ]; then
    DOMAIN="$1"
    echo "Using domain: $DOMAIN"
    SSL_MODE="letsencrypt"
else
    echo "No domain provided - will use self-signed certificate for IP access"
    SSL_MODE="selfsigned"
fi

echo "3. Creating SSL certificates..."

if [ "$SSL_MODE" = "letsencrypt" ] && [ -n "$DOMAIN" ]; then
    echo "Setting up Let's Encrypt certificate for domain: $DOMAIN"
    sudo certbot certonly --standalone -d "$DOMAIN" --non-interactive --agree-tos -m admin@calpion.com
    
    if [ $? -eq 0 ]; then
        SSL_CERT="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
        SSL_KEY="/etc/letsencrypt/live/$DOMAIN/privkey.pem"
        echo "Let's Encrypt certificate created successfully"
    else
        echo "Let's Encrypt failed, falling back to self-signed"
        SSL_MODE="selfsigned"
    fi
fi

if [ "$SSL_MODE" = "selfsigned" ]; then
    echo "Creating self-signed certificate..."
    sudo mkdir -p /etc/ssl/servicedesk
    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/ssl/servicedesk/server.key \
        -out /etc/ssl/servicedesk/server.crt \
        -subj "/C=US/ST=State/L=City/O=Calpion/CN=$SERVER_IP"
    
    SSL_CERT="/etc/ssl/servicedesk/server.crt"
    SSL_KEY="/etc/ssl/servicedesk/server.key"
    echo "Self-signed certificate created"
fi

echo "4. Setting up Nginx reverse proxy..."
sudo tee /etc/nginx/sites-available/servicedesk << EOF
server {
    listen 80;
    server_name $SERVER_IP${DOMAIN:+ $DOMAIN};
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $SERVER_IP${DOMAIN:+ $DOMAIN};

    ssl_certificate $SSL_CERT;
    ssl_certificate_key $SSL_KEY;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256;
    ssl_prefer_server_ciphers on;

    location / {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/servicedesk /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

echo "5. Testing Nginx configuration..."
sudo nginx -t

if [ $? -eq 0 ]; then
    sudo systemctl enable nginx
    sudo systemctl restart nginx
    echo "Nginx configured successfully"
else
    echo "Nginx configuration error"
    exit 1
fi

echo "6. Updating firewall rules..."
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 22/tcp
echo "y" | sudo ufw enable

echo "7. Starting service desk..."
sudo systemctl start servicedesk.service
sudo systemctl enable servicedesk.service

sleep 5

echo "8. Testing HTTPS setup..."
echo "Service status:"
sudo systemctl status servicedesk.service --no-pager -l

echo ""
echo "Nginx status:"
sudo systemctl status nginx --no-pager

echo ""
echo "Testing HTTPS connection:"
curl -k -I https://localhost/ | head -3

echo ""
echo "=== HTTPS Setup Complete ==="
echo "Access your service desk at:"
echo "  HTTPS: https://$SERVER_IP"
if [ -n "$DOMAIN" ]; then
    echo "  Domain: https://$DOMAIN"
fi
echo ""
echo "Note: If using self-signed certificate, browsers will show security warning"
echo "Click 'Advanced' and 'Proceed to site' to continue"