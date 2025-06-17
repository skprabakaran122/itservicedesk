#!/bin/bash

# Copy IT Service Desk files to server
# Run this script FROM your local machine or from where you have the source code

echo "========================================="
echo "IT Service Desk - File Transfer to Server"
echo "========================================="
echo ""

# Check if we have the required files
if [ ! -f "package.json" ]; then
    echo "ERROR: package.json not found in current directory"
    echo "Please run this script from the root of your IT Service Desk project"
    exit 1
fi

if [ ! -d "server" ]; then
    echo "ERROR: server directory not found"
    echo "Please run this script from the root of your IT Service Desk project"
    exit 1
fi

# Get server details
read -p "Server IP address: " SERVER_IP
read -p "Server username (usually ubuntu): " SERVER_USER
read -p "SSH key path (leave empty for password auth): " SSH_KEY

echo ""
echo "Preparing files for upload..."

# Create a temporary directory with only necessary files
mkdir -p /tmp/servicedesk-deploy
cd /tmp/servicedesk-deploy

# Copy essential files (exclude node_modules, .git, etc.)
rsync -av --exclude='node_modules' \
         --exclude='.git' \
         --exclude='dist' \
         --exclude='.env' \
         --exclude='uploads' \
         --exclude='*.log' \
         --exclude='.replit' \
         --exclude='attached_assets' \
         --exclude='*.md' \
         --exclude='*.sh' \
         $OLDPWD/ ./

echo "Files prepared for upload"
echo ""

# Prepare SSH command
if [ -n "$SSH_KEY" ]; then
    SSH_CMD="ssh -i $SSH_KEY"
    SCP_CMD="scp -i $SSH_KEY"
    RSYNC_CMD="rsync -e 'ssh -i $SSH_KEY'"
else
    SSH_CMD="ssh"
    SCP_CMD="scp"
    RSYNC_CMD="rsync"
fi

echo "Uploading files to server..."

# Create directory on server
$SSH_CMD $SERVER_USER@$SERVER_IP "sudo mkdir -p /var/www/servicedesk && sudo chown -R $SERVER_USER:$SERVER_USER /var/www/servicedesk"

# Upload files
eval "$RSYNC_CMD -av ./ $SERVER_USER@$SERVER_IP:/var/www/servicedesk/"

if [ $? -eq 0 ]; then
    echo "✓ Files uploaded successfully"
else
    echo "✗ File upload failed"
    exit 1
fi

# Set proper permissions
$SSH_CMD $SERVER_USER@$SERVER_IP "sudo chown -R $SERVER_USER:$SERVER_USER /var/www/servicedesk"

echo ""
echo "Upload completed! You can now run the deployment script on your server:"
echo ""
echo "ssh $SERVER_USER@$SERVER_IP"
echo "cd /var/www/servicedesk"
echo "./deploy_to_server.sh"
echo ""

# Cleanup
cd $OLDPWD
rm -rf /tmp/servicedesk-deploy