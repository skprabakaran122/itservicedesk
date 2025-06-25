#!/bin/bash

# SSL Setup for Docker on Ubuntu
# Configures Let's Encrypt SSL with Nginx reverse proxy

set -e

# Configuration
DOMAIN=${1:-"yourdomain.com"}
EMAIL=${2:-"admin@yourdomain.com"}
APP_NAME="itservicedesk"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Check if domain is provided
if [ "$DOMAIN" = "yourdomain.com" ]; then
    error "Please provide your domain: ./ubuntu-docker-ssl.sh your-domain.com your-email@domain.com"
fi

log "Setting up SSL for Docker deployment on domain: $DOMAIN"

# Install Certbot
log "Installing Certbot..."
sudo apt update
sudo apt install -y snapd
sudo snap install core; sudo snap refresh core
sudo snap install --classic certbot
sudo ln -sf /snap/bin/certbot /usr/bin/certbot

# Update Nginx configuration for SSL
log "Updating Nginx configuration for SSL and Docker..."
sudo tee /etc/nginx/sites-available/$APP_NAME > /dev/null << EOF
# HTTP server - redirect to HTTPS
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    
    # Let's Encrypt challenge
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    # Redirect all other traffic to HTTPS
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

# HTTPS server with Docker proxy
server {
    listen 443 ssl http2;
    server_name $DOMAIN www.$DOMAIN;

    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    ssl_trusted_certificate /etc/letsencrypt/live/$DOMAIN/chain.pem;

    # SSL Security Settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_stapling on;
    ssl_stapling_verify on;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' 'unsafe-inline' 'unsafe-eval' data: blob:; img-src 'self' data: https:; font-src 'self' data: https:;" always;

    # File upload size
    client_max_body_size 10M;

    # Docker container proxy
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_cache_bypass \$http_upgrade;
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
        
        # Additional headers for Docker
        proxy_set_header X-Forwarded-Host \$server_name;
        proxy_set_header X-Forwarded-Server \$host;
    }

    # Health check endpoint
    location /health {
        proxy_pass http://127.0.0.1:5000/health;
        access_log off;
    }

    # Static files served directly by Nginx
    location /uploads {
        alias /opt/itservicedesk/uploads;
        expires 1y;
        add_header Cache-Control "public, immutable";
        
        # Security for uploaded files
        location ~* \.(php|phtml|pl|py|jsp|asp|sh|cgi)\$ {
            deny all;
        }
    }

    # Favicon and robots
    location = /favicon.ico {
        log_not_found off;
        access_log off;
    }
    
    location = /robots.txt {
        log_not_found off;
        access_log off;
    }
}
EOF

# Test Nginx configuration
log "Testing Nginx configuration..."
sudo nginx -t

# Reload Nginx
log "Reloading Nginx..."
sudo systemctl reload nginx

# Create web root for Let's Encrypt
sudo mkdir -p /var/www/html

# Obtain SSL certificate
log "Obtaining SSL certificate from Let's Encrypt..."
sudo certbot --nginx -d $DOMAIN -d www.$DOMAIN --non-interactive --agree-tos --email $EMAIL --redirect

# Set up automatic renewal
log "Setting up automatic SSL renewal..."
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer

# Create renewal hook for Nginx and Docker
sudo mkdir -p /etc/letsencrypt/renewal-hooks/post
sudo tee /etc/letsencrypt/renewal-hooks/post/nginx-docker-reload.sh > /dev/null << 'EOF'
#!/bin/bash
# Reload Nginx after SSL renewal
systemctl reload nginx

# Optional: Restart Docker container if needed
# docker-compose -f /opt/itservicedesk/docker-compose.ubuntu.yml restart app
EOF
sudo chmod +x /etc/letsencrypt/renewal-hooks/post/nginx-docker-reload.sh

# Test automatic renewal
log "Testing automatic renewal..."
sudo certbot renew --dry-run

# Update firewall for HTTPS
log "Updating firewall for HTTPS..."
sudo ufw allow 'Nginx Full'

# Update Docker Compose for HTTPS
log "Updating Docker environment for HTTPS..."
cd /opt/itservicedesk

# Add HTTPS configuration to environment
if ! grep -q "HTTPS_ENABLED" .env.prod; then
    cat >> .env.prod << EOF

# HTTPS Configuration
HTTPS_ENABLED=true
DOMAIN_NAME=$DOMAIN
SSL_CERT_PATH=/etc/letsencrypt/live/$DOMAIN/fullchain.pem
SSL_KEY_PATH=/etc/letsencrypt/live/$DOMAIN/privkey.pem
EOF
fi

# Restart application to apply changes
log "Restarting application with HTTPS configuration..."
./manage.sh restart

# Verify SSL setup
log "Verifying SSL setup..."
sleep 5

if curl -f -s https://$DOMAIN/health > /dev/null; then
    log "✅ HTTPS health check passed"
else
    warn "HTTPS health check failed - check application logs"
fi

# Display SSL information
echo ""
log "✅ SSL setup completed successfully!"
echo ""
echo "🔒 SSL Certificate Information:"
sudo certbot certificates | grep -A 10 "$DOMAIN"
echo ""
echo "🌐 Secure URLs:"
echo "  - HTTPS: https://$DOMAIN"
echo "  - HTTPS WWW: https://www.$DOMAIN"
echo "  - Health Check: https://$DOMAIN/health"
echo ""
echo "🔄 SSL Management Commands:"
echo "  - Renew certificates: sudo certbot renew"
echo "  - Check renewal timer: sudo systemctl status certbot.timer"
echo "  - View certificates: sudo certbot certificates"
echo "  - Test renewal: sudo certbot renew --dry-run"
echo ""
echo "🐳 Docker Management:"
echo "  - Restart app: /opt/itservicedesk/manage.sh restart"
echo "  - View logs: /opt/itservicedesk/manage.sh logs"
echo "  - Check status: /opt/itservicedesk/monitor.sh"
echo ""
log "SSL certificate will auto-renew every 60 days"
log "Docker application is now secured with HTTPS"