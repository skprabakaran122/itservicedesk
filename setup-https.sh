#!/bin/bash

# HTTPS Setup Script for Calpion IT Service Desk
# This script helps configure SSL certificates for HTTPS

set -e

echo "🔒 Calpion IT Service Desk - HTTPS Setup"
echo "========================================"

# Create SSL directory
mkdir -p ssl

# Function to generate self-signed certificate for development
generate_self_signed() {
    echo "Generating self-signed certificate for development..."
    
    openssl req -x509 -newkey rsa:4096 -keyout ssl/key.pem -out ssl/cert.pem -days 365 -nodes \
        -subj "/C=US/ST=State/L=City/O=Calpion/OU=IT/CN=localhost"
    
    echo "✅ Self-signed certificate generated in ./ssl/"
    echo "   - Certificate: ./ssl/cert.pem"
    echo "   - Private Key: ./ssl/key.pem"
    echo ""
    echo "⚠️  Note: Self-signed certificates will show browser warnings"
    echo "   For production, use a proper SSL certificate from a CA"
}

# Function to setup Let's Encrypt certificate
setup_letsencrypt() {
    local domain=$1
    local email=$2
    
    echo "Setting up Let's Encrypt certificate for domain: $domain"
    
    # Install certbot if not present
    if ! command -v certbot &> /dev/null; then
        echo "Installing certbot..."
        sudo apt update
        sudo apt install -y certbot
    fi
    
    # Stop any running services on port 80
    echo "Stopping services on port 80..."
    sudo fuser -k 80/tcp || true
    
    # Generate certificate
    sudo certbot certonly --standalone \
        --email "$email" \
        --agree-tos \
        --no-eff-email \
        -d "$domain"
    
    # Copy certificates to project directory
    sudo cp "/etc/letsencrypt/live/$domain/fullchain.pem" ssl/cert.pem
    sudo cp "/etc/letsencrypt/live/$domain/privkey.pem" ssl/key.pem
    sudo chown $USER:$USER ssl/cert.pem ssl/key.pem
    
    echo "✅ Let's Encrypt certificate installed"
    echo "   - Certificate: ./ssl/cert.pem"
    echo "   - Private Key: ./ssl/key.pem"
    
    # Setup auto-renewal
    echo "Setting up auto-renewal..."
    (crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -
    
    echo "✅ Auto-renewal configured (runs daily at noon)"
}

# Function to setup custom certificate
setup_custom_cert() {
    echo "Setting up custom certificate..."
    echo "Please place your certificate files in the ./ssl/ directory:"
    echo "  - Certificate: ./ssl/cert.pem"
    echo "  - Private Key: ./ssl/key.pem"
    echo ""
    echo "You can also set environment variables:"
    echo "  - SSL_CERT: Certificate content"
    echo "  - SSL_KEY: Private key content"
}

# Main menu
echo "Choose SSL certificate setup option:"
echo "1) Generate self-signed certificate (development)"
echo "2) Setup Let's Encrypt certificate (production)"
echo "3) Use custom certificate"
echo "4) Exit"
echo ""

read -p "Enter your choice (1-4): " choice

case $choice in
    1)
        generate_self_signed
        ;;
    2)
        read -p "Enter your domain name: " domain
        read -p "Enter your email address: " email
        setup_letsencrypt "$domain" "$email"
        ;;
    3)
        setup_custom_cert
        ;;
    4)
        echo "Exiting..."
        exit 0
        ;;
    *)
        echo "Invalid choice. Exiting..."
        exit 1
        ;;
esac

echo ""
echo "🚀 HTTPS Setup Complete!"
echo ""
echo "Next steps:"
echo "1. Start your server with: npm run dev"
echo "2. Access your application at:"
echo "   - HTTPS: https://localhost:5001"
echo "   - HTTP:  http://localhost:5000 (redirects to HTTPS)"
echo ""
echo "For production deployment:"
echo "1. Update firewall rules to allow ports 80 and 443"
echo "2. Configure reverse proxy (nginx/apache) if needed"
echo "3. Update DNS records to point to your server"