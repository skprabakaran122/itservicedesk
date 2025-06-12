#!/bin/bash

# Complete Fresh Deployment Script - Service Desk Application
# Run this script on your Ubuntu server as the ubuntu user

set -e  # Exit on any error

echo "Starting fresh deployment of Service Desk application..."

# Configuration
PROJECT_DIR="/home/ubuntu/servicedesk"
DB_NAME="servicedesk"
APP_PORT="5000"

# Step 1: Clean existing installation
echo "Step 1: Cleaning existing installation..."
pm2 stop all 2>/dev/null || true
pm2 delete all 2>/dev/null || true
sudo rm -rf "$PROJECT_DIR" 2>/dev/null || true

# Step 2: Install system dependencies
echo "Step 2: Installing system dependencies..."
sudo apt update
sudo apt install -y postgresql postgresql-contrib curl git

# Ensure PostgreSQL is running
sudo systemctl enable postgresql
sudo systemctl start postgresql

# Step 3: Install Node.js 20
echo "Step 3: Installing Node.js 20..."
if ! command -v node &> /dev/null || [[ "$(node -v)" != "v20"* ]]; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

# Install global packages
sudo npm install -g pm2 tsx typescript

# Step 4: Setup PostgreSQL database
echo "Step 4: Setting up PostgreSQL database..."
sudo -u postgres psql << EOF
DROP DATABASE IF EXISTS $DB_NAME;
CREATE DATABASE $DB_NAME;
\q
EOF

# Step 5: Clone application repository
echo "Step 5: Cloning application repository..."
cd /home/ubuntu
git clone https://github.com/skprabakaran122/itservicedesk.git servicedesk
cd servicedesk

# Step 6: Install application dependencies
echo "Step 6: Installing application dependencies..."
npm install --production

# Step 7: Create environment configuration
echo "Step 7: Creating environment configuration..."
cat > .env << EOF
NODE_ENV=production
PORT=$APP_PORT
DATABASE_URL=postgresql://postgres@localhost:5432/$DB_NAME
SENDGRID_API_KEY=configure_in_admin_console
EOF

# Step 8: Setup database schema
echo "Step 8: Setting up database schema..."
export DATABASE_URL="postgresql://postgres@localhost:5432/$DB_NAME"
npm run db:push

# Step 9: Create PM2 ecosystem configuration
echo "Step 9: Creating PM2 configuration..."
cat > ecosystem.config.js << EOF
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'server/index.ts',
    interpreter: 'node',
    interpreter_args: '--import tsx',
    instances: 1,
    exec_mode: 'fork',
    env: {
      NODE_ENV: 'production',
      PORT: $APP_PORT,
      DATABASE_URL: 'postgresql://postgres@localhost:5432/$DB_NAME',
      SENDGRID_API_KEY: 'configure_in_admin_console'
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

# Step 10: Create logs directory and start application
echo "Step 10: Starting application..."
mkdir -p logs

# Start with PM2
pm2 start ecosystem.config.js
pm2 save
pm2 startup

# Step 11: Configure firewall (optional)
echo "Step 11: Configuring firewall..."
sudo ufw allow $APP_PORT 2>/dev/null || true

# Step 12: Verify deployment
echo "Step 12: Verifying deployment..."
sleep 5

echo "Checking application status..."
pm2 status

echo "Recent application logs:"
pm2 logs servicedesk --lines 10

# Step 13: Test application accessibility
echo "Step 13: Testing application..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost:$APP_PORT | grep -q "200\|302"; then
    echo "✅ Application is responding successfully"
else
    echo "⚠️  Application may still be starting up"
fi

echo ""
echo "🎉 Deployment Complete!"
echo ""
echo "Application Details:"
echo "  URL: http://$(curl -s ifconfig.me):$APP_PORT"
echo "  Local: http://localhost:$APP_PORT"
echo "  Admin Login: john.doe / password123"
echo ""
echo "Next Steps:"
echo "1. Access the application URL above"
echo "2. Login with admin credentials"
echo "3. Go to Admin Console > Email Settings"
echo "4. Configure your SendGrid API key"
echo "5. Test email functionality"
echo ""
echo "Useful Commands:"
echo "  View logs: pm2 logs servicedesk"
echo "  Restart app: pm2 restart servicedesk"
echo "  Check status: pm2 status"
echo "  Stop app: pm2 stop servicedesk"
echo ""
echo "Application successfully deployed!"