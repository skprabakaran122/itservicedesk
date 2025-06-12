#!/bin/bash

# Clean Service Desk Deployment - Complete Solution
echo "Service Desk - Clean Deployment Starting..."

# Configuration
PROJECT_DIR="/home/ubuntu/servicedesk"
APP_PORT="5000"

# Step 1: Complete cleanup
echo "Cleaning existing installation..."
pm2 stop all 2>/dev/null || true
pm2 delete all 2>/dev/null || true
sudo rm -rf "$PROJECT_DIR" 2>/dev/null || true

# Step 2: System dependencies
echo "Installing system dependencies..."
sudo apt update -y
sudo apt install -y curl git build-essential

# Step 3: Node.js 20 installation
echo "Installing Node.js 20..."
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Verify Node.js version
node_version=$(node -v)
echo "Node.js installed: $node_version"

# Step 4: Global packages
echo "Installing global packages..."
sudo npm install -g pm2 tsx typescript

# Step 5: Clone repository
echo "Cloning repository..."
cd /home/ubuntu
git clone https://github.com/skprabakaran122/itservicedesk.git servicedesk
cd servicedesk

# Step 6: Install dependencies
echo "Installing dependencies..."
npm install

# Step 7: Environment setup
echo "Creating environment configuration..."
cat > .env << EOF
NODE_ENV=production
PORT=$APP_PORT
DATABASE_URL=$DATABASE_URL
SENDGRID_API_KEY=configure_in_admin_console
EOF

# Step 8: Database schema
echo "Setting up database schema..."
npm run db:push

# Step 9: PM2 configuration
echo "Creating PM2 configuration..."
cat > ecosystem.config.cjs << 'EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'npm',
    args: 'run dev',
    instances: 1,
    exec_mode: 'fork',
    env: {
      NODE_ENV: 'production',
      PORT: 5000
    },
    error_file: './logs/pm2-error.log',
    out_file: './logs/pm2-out.log',
    log_file: './logs/pm2-combined.log',
    time: true,
    max_memory_restart: '1G',
    restart_delay: 4000,
    max_restarts: 5,
    min_uptime: '10s'
  }]
};
EOF

# Step 10: Start application
echo "Starting application..."
mkdir -p logs
pm2 start ecosystem.config.cjs
pm2 save
pm2 startup

# Step 11: Firewall
echo "Configuring firewall..."
sudo ufw allow $APP_PORT/tcp 2>/dev/null || true

# Step 12: Verification
echo "Verifying deployment..."
sleep 10

# Check PM2 status
pm2 status

# Test application
echo "Testing application response..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost:$APP_PORT | grep -q "200\|302"; then
    echo "Application is responding successfully"
else
    echo "Application may still be starting..."
fi

# Get public IP
PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "your-server-ip")

echo ""
echo "DEPLOYMENT COMPLETE"
echo "=================="
echo "Application URL: http://$PUBLIC_IP:$APP_PORT"
echo "Admin Login: john.doe / password123"
echo ""
echo "Management Commands:"
echo "  pm2 logs servicedesk    # View logs"
echo "  pm2 restart servicedesk # Restart app"
echo "  pm2 stop servicedesk    # Stop app"
echo "  pm2 status              # Check status"
echo ""
echo "Next Steps:"
echo "1. Access the application URL"
echo "2. Login with admin credentials"
echo "3. Navigate to Admin Console > Email Settings"
echo "4. Configure SendGrid API key for email notifications"
echo ""

# Show recent logs
echo "Recent application logs:"
pm2 logs servicedesk --lines 15