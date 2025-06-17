#!/bin/bash

# Create deployment package for IT Service Desk
# This creates a complete package ready for server deployment

echo "Creating deployment package..."

# Create deployment directory
mkdir -p deployment-package
cd deployment-package

# Copy application files (excluding unnecessary files)
echo "Copying application files..."
rsync -av --exclude='node_modules' \
         --exclude='.git' \
         --exclude='dist' \
         --exclude='uploads' \
         --exclude='*.log' \
         --exclude='.replit' \
         --exclude='attached_assets' \
         --exclude='deployment-package' \
         ../ ./

# Copy deployment scripts
cp ../deploy_to_server.sh ./
cp ../clean_and_deploy.sh ./
chmod +x *.sh

# Create a simple deployment guide
cat > DEPLOYMENT_INSTRUCTIONS.txt << 'EOF'
IT Service Desk - Server Deployment Instructions
==============================================

1. Upload this entire deployment-package folder to your Ubuntu server

2. Extract and navigate to the folder:
   cd deployment-package

3. Run the deployment script:
   ./deploy_to_server.sh

The script will:
- Install Node.js, PostgreSQL, Nginx
- Configure database and security
- Build and start the application
- Set up SSL certificates
- Configure firewall

Your application will be available at:
- HTTP: http://your-server-ip
- HTTPS: https://your-server-ip

Default admin login:
- Username: admin
- Password: admin (change after first login)

For clean installation (removes existing):
./clean_and_deploy.sh

For updates:
./update.sh (created after deployment)
EOF

echo "✓ Deployment package created in 'deployment-package' directory"
echo ""
echo "To deploy to your server:"
echo "1. Download/copy the 'deployment-package' folder to your server"
echo "2. SSH to your server: ssh user@your-server-ip"
echo "3. Navigate to the folder: cd deployment-package"
echo "4. Run: ./deploy_to_server.sh"
echo ""
echo "Package contents:"
ls -la