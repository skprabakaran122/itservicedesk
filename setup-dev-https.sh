#!/bin/bash

# Setup Development HTTPS with Nginx and Self-Signed Certificate
echo "Setting up development HTTPS with nginx..."

# Check if running on Replit (has specific constraints)
if [ -n "$REPL_ID" ]; then
    echo "Detected Replit environment - configuring for container deployment"
    DOMAIN="localhost"
    SERVER_IP="0.0.0.0"
else
    echo "Local development environment detected"
    DOMAIN="localhost" 
    SERVER_IP="127.0.0.1"
fi

# Create SSL directory
mkdir -p ssl

# Generate self-signed certificate
echo "Generating self-signed SSL certificate..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout ssl/dev-private.key \
    -out ssl/dev-certificate.crt \
    -subj "/C=US/ST=CA/L=San Francisco/O=Calpion/OU=IT/CN=$DOMAIN"

if [ $? -eq 0 ]; then
    echo "SSL certificate generated successfully"
else
    echo "Failed to generate SSL certificate"
    exit 1
fi

# Create nginx configuration for development
cat > nginx-dev.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    upstream app {
        server 127.0.0.1:5000;
    }

    # HTTP to HTTPS redirect
    server {
        listen 80;
        server_name localhost;
        return 301 https://$server_name$request_uri;
    }

    # HTTPS server
    server {
        listen 443 ssl;
        server_name localhost;

        # SSL Configuration
        ssl_certificate ssl/dev-certificate.crt;
        ssl_certificate_key ssl/dev-private.key;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
        ssl_prefer_server_ciphers off;

        # Security headers
        add_header X-Frame-Options DENY;
        add_header X-Content-Type-Options nosniff;
        add_header X-XSS-Protection "1; mode=block";
        add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload";

        # Proxy settings
        location / {
            proxy_pass http://app;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_cache_bypass $http_upgrade;
            proxy_read_timeout 86400;
        }

        # Health check endpoint
        location /health {
            proxy_pass http://app/api/health;
            access_log off;
        }
    }
}
EOF

echo "Nginx development configuration created"

# Function to start nginx in background
start_nginx() {
    echo "Starting nginx with development configuration..."
    if command -v nginx >/dev/null 2>&1; then
        # Test nginx configuration
        nginx -t -c $(pwd)/nginx-dev.conf
        if [ $? -eq 0 ]; then
            # Start nginx in background
            nginx -c $(pwd)/nginx-dev.conf &
            NGINX_PID=$!
            echo "Nginx started with PID: $NGINX_PID"
            echo $NGINX_PID > nginx-dev.pid
            
            # Give nginx time to start
            sleep 2
            
            # Test if nginx is running
            if kill -0 $NGINX_PID 2>/dev/null; then
                echo "✓ Nginx is running successfully"
                echo "✓ HTTPS available at: https://localhost"
                echo "✓ HTTP redirects to HTTPS automatically"
                return 0
            else
                echo "✗ Failed to start nginx"
                return 1
            fi
        else
            echo "✗ Nginx configuration test failed"
            return 1
        fi
    else
        echo "Installing nginx..."
        if [ -n "$REPL_ID" ]; then
            # On Replit, we need to use the package manager
            echo "Use the package manager to install nginx system dependency"
            return 1
        else
            # On local systems
            if command -v apt-get >/dev/null 2>&1; then
                apt-get update && apt-get install -y nginx
            elif command -v yum >/dev/null 2>&1; then
                yum install -y nginx
            else
                echo "Please install nginx manually for your system"
                return 1
            fi
        fi
    fi
}

# Function to stop nginx
stop_nginx() {
    if [ -f nginx-dev.pid ]; then
        NGINX_PID=$(cat nginx-dev.pid)
        if kill -0 $NGINX_PID 2>/dev/null; then
            kill $NGINX_PID
            echo "Nginx stopped"
        fi
        rm -f nginx-dev.pid
    fi
}

# Handle script arguments
case "$1" in
    start)
        start_nginx
        ;;
    stop)
        stop_nginx
        ;;
    restart)
        stop_nginx
        sleep 1
        start_nginx
        ;;
    status)
        if [ -f nginx-dev.pid ]; then
            NGINX_PID=$(cat nginx-dev.pid)
            if kill -0 $NGINX_PID 2>/dev/null; then
                echo "Nginx is running (PID: $NGINX_PID)"
                echo "HTTPS: https://localhost"
                echo "Health check: https://localhost/health"
            else
                echo "Nginx is not running"
            fi
        else
            echo "Nginx is not running"
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        echo ""
        echo "Development HTTPS setup for Calpion IT Service Desk"
        echo "This script configures nginx with self-signed certificates"
        echo ""
        echo "Commands:"
        echo "  start   - Start nginx with HTTPS configuration"
        echo "  stop    - Stop nginx"
        echo "  restart - Restart nginx"
        echo "  status  - Check nginx status"
        echo ""
        echo "After starting, access the application at:"
        echo "  https://localhost (HTTPS)"
        echo "  http://localhost (redirects to HTTPS)"
        exit 1
        ;;
esac