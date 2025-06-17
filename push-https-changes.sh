#!/bin/bash

# Quick script to push HTTPS changes to existing server
# Usage: ./push-https-changes.sh SERVER_IP PPK_KEY_PATH

SERVER_IP=$1
PPK_KEY=$2
SERVER_USER="ubuntu"
DEPLOY_DIR="/home/ubuntu/servicedesk"

if [ -z "$SERVER_IP" ] || [ -z "$PPK_KEY" ]; then
    echo "Usage: ./push-https-changes.sh SERVER_IP PPK_KEY_PATH"
    echo "Example: ./push-https-changes.sh 192.168.1.100 my-key.ppk"
    exit 1
fi

# Convert PPK to PEM if needed
if [[ "$PPK_KEY" == *.ppk ]]; then
    echo "Converting PPK to PEM..."
    puttygen "$PPK_KEY" -O private-openssh -o "${PPK_KEY%.ppk}.pem"
    SSH_KEY="${PPK_KEY%.ppk}.pem"
    chmod 600 "$SSH_KEY"
else
    SSH_KEY="$PPK_KEY"
fi

echo "Pushing HTTPS changes to $SERVER_IP..."

# Create update package with only changed files
tar --exclude=node_modules --exclude=.git --exclude=ssl --exclude=uploads -czf https-update.tar.gz \
    server/index.ts \
    package.json \
    .env \
    setup-https.sh \
    HTTPS_DEPLOYMENT_GUIDE.md

# Copy to server
scp -i "$SSH_KEY" https-update.tar.gz "$SERVER_USER@$SERVER_IP:$DEPLOY_DIR/"

# Update on server
ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_IP" << EOF
cd $DEPLOY_DIR

# Extract updates
tar -xzf https-update.tar.gz
rm https-update.tar.gz

# Install any new dependencies
npm install

# Generate SSL certificates if not present
if [ ! -d "ssl" ]; then
    mkdir -p ssl
    openssl req -x509 -newkey rsa:4096 -keyout ssl/key.pem -out ssl/cert.pem -days 365 -nodes \
        -subj "/C=US/ST=State/L=City/O=Calpion/OU=IT/CN=\$(curl -s http://checkip.amazonaws.com)"
    chmod 600 ssl/key.pem
    chmod 644 ssl/cert.pem
fi

# Update firewall for HTTPS
sudo ufw allow 5001/tcp

# Restart application with PM2
pm2 restart calpion-service-desk || pm2 start ecosystem.config.cjs --name calpion-service-desk

# Show status
pm2 status
pm2 logs calpion-service-desk --lines 5

echo ""
echo "HTTPS update complete!"
echo "Access your application at:"
echo "  HTTPS: https://$SERVER_IP:5001"
echo "  HTTP:  http://$SERVER_IP:5000 (redirects to HTTPS)"
EOF

# Clean up
rm https-update.tar.gz

echo "HTTPS changes pushed successfully!"