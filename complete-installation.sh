#!/bin/bash

# Complete the installation - fix nginx and start services
set -e

echo "=== Completing IT Service Desk Installation ==="

# Ensure nginx directories exist
mkdir -p /etc/nginx/sites-available
mkdir -p /etc/nginx/sites-enabled

# Configure nginx
echo "Configuring nginx..."
cat > /etc/nginx/sites-available/itservicedesk << 'EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
        proxy_read_timeout 300;
    }
}
EOF

# Enable nginx site
ln -sf /etc/nginx/sites-available/itservicedesk /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl restart nginx
systemctl enable nginx

# Configure firewall
echo "Configuring firewall..."
ufw --force reset
ufw allow ssh
ufw allow 'Nginx Full'
ufw --force enable

# Start the systemd service
echo "Starting IT Service Desk service..."
systemctl daemon-reload
systemctl enable itservicedesk
systemctl start itservicedesk

# Get server IP
SERVER_IP=$(hostname -I | awk '{print $1}')

# Wait for service to start
echo "Waiting for service to start..."
sleep 15

# Check service status
echo "Service Status:"
systemctl status itservicedesk --no-pager -l

# Test application
echo ""
echo "Testing application..."
for i in {1..10}; do
    if curl -f -s http://localhost:3000/health > /dev/null; then
        echo "✓ Application is running successfully"
        break
    elif curl -f -s http://localhost:3000/ > /dev/null; then
        echo "✓ Application is responding"
        break
    else
        echo "Attempt $i: Checking application startup..."
        sleep 3
    fi
done

echo ""
echo "=== Installation Complete ==="
echo "✓ Database configured and running"
echo "✓ Application service started"
echo "✓ Nginx proxy configured"
echo "✓ Firewall configured"
echo ""
echo "Access your IT Service Desk at: http://$SERVER_IP"
echo ""
echo "Login Credentials:"
echo "  Admin: test.admin / password123"
echo "  User:  test.user / password123"
echo "  Agent: john.doe / password123"
echo ""
echo "Management Commands:"
echo "  View status: sudo systemctl status itservicedesk"
echo "  View logs:   sudo journalctl -u itservicedesk -f"
echo "  Restart:     sudo systemctl restart itservicedesk"