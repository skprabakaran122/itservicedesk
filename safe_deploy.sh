#!/bin/bash

# Safe Deployment Script with Error Handling
# Run this script on your Ubuntu server

echo "=== Service Desk Deployment Script ==="
echo "Starting deployment at $(date)"

# Function to handle errors
handle_error() {
    echo "ERROR: $1"
    echo "Deployment failed at step: $2"
    read -p "Press Enter to continue or Ctrl+C to exit..."
}

# Function to check command success
check_success() {
    if [ $? -eq 0 ]; then
        echo "✓ $1 completed successfully"
    else
        handle_error "$1 failed" "$2"
        return 1
    fi
}

# Configuration
PROJECT_DIR="/home/ubuntu/servicedesk"
DB_NAME="servicedesk"
APP_PORT="5000"

echo "Configuration:"
echo "  Project Directory: $PROJECT_DIR"
echo "  Database Name: $DB_NAME"
echo "  Application Port: $APP_PORT"
echo ""

# Step 1: Check if running as correct user
echo "Step 1: Checking user permissions..."
if [ "$USER" != "ubuntu" ]; then
    echo "WARNING: Not running as ubuntu user. Current user: $USER"
    read -p "Continue anyway? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Step 2: Clean existing installation
echo "Step 2: Cleaning existing installation..."
pm2 stop all 2>/dev/null || echo "No PM2 processes to stop"
pm2 delete all 2>/dev/null || echo "No PM2 processes to delete"

if [ -d "$PROJECT_DIR" ]; then
    echo "Removing existing project directory..."
    rm -rf "$PROJECT_DIR" || handle_error "Failed to remove project directory" "cleanup"
fi

# Step 3: Update system packages
echo "Step 3: Updating system packages..."
sudo apt update || handle_error "Failed to update package list" "system-update"
check_success "System update" "system-update"

# Step 4: Install PostgreSQL if not present
echo "Step 4: Installing PostgreSQL..."
if ! command -v psql &> /dev/null; then
    sudo apt install -y postgresql postgresql-contrib || handle_error "Failed to install PostgreSQL" "postgresql-install"
    check_success "PostgreSQL installation" "postgresql-install"
else
    echo "✓ PostgreSQL already installed"
fi

# Start PostgreSQL service
sudo systemctl enable postgresql
sudo systemctl start postgresql
check_success "PostgreSQL service start" "postgresql-service"

# Step 5: Install Node.js 20 if not present
echo "Step 5: Checking Node.js installation..."
if ! command -v node &> /dev/null; then
    echo "Installing Node.js 20..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - || handle_error "Failed to add Node.js repository" "nodejs-repo"
    sudo apt-get install -y nodejs || handle_error "Failed to install Node.js" "nodejs-install"
    check_success "Node.js installation" "nodejs-install"
else
    NODE_VERSION=$(node -v)
    echo "✓ Node.js already installed: $NODE_VERSION"
fi

# Install global packages
echo "Installing global npm packages..."
sudo npm install -g pm2 tsx typescript || handle_error "Failed to install global packages" "npm-global"
check_success "Global npm packages" "npm-global"

# Step 6: Setup PostgreSQL database
echo "Step 6: Setting up PostgreSQL database..."
sudo -u postgres psql << EOF || handle_error "Failed to setup database" "database-setup"
DROP DATABASE IF EXISTS $DB_NAME;
CREATE DATABASE $DB_NAME;
SELECT 'Database created successfully' as status;
\q
EOF
check_success "Database setup" "database-setup"

# Step 7: Clone application repository
echo "Step 7: Cloning application repository..."
cd /home/ubuntu || handle_error "Failed to navigate to home directory" "navigation"

# Clone with error handling
if ! git clone https://github.com/skprabakaran122/itservicedesk.git servicedesk; then
    handle_error "Failed to clone repository" "git-clone"
    echo "Trying alternative clone method..."
    git clone https://github.com/skprabakaran122/itservicedesk.git servicedesk --depth=1 || handle_error "Git clone failed completely" "git-clone-alt"
fi

cd servicedesk || handle_error "Failed to enter project directory" "project-navigation"
check_success "Repository clone" "git-clone"

# Step 8: Install application dependencies
echo "Step 8: Installing application dependencies..."
npm install || handle_error "Failed to install npm dependencies" "npm-install"
check_success "NPM dependencies" "npm-install"

# Step 9: Create environment configuration
echo "Step 9: Creating environment configuration..."
cat > .env << EOF
NODE_ENV=production
PORT=$APP_PORT
DATABASE_URL=postgresql://postgres@localhost:5432/$DB_NAME
SENDGRID_API_KEY=configure_in_admin_console
EOF
check_success "Environment configuration" "env-config"

# Step 10: Setup database schema
echo "Step 10: Setting up database schema..."
export DATABASE_URL="postgresql://postgres@localhost:5432/$DB_NAME"
npm run db:push || handle_error "Failed to setup database schema" "db-schema"
check_success "Database schema" "db-schema"

# Step 11: Create PM2 configuration
echo "Step 11: Creating PM2 configuration..."
cat > ecosystem.config.js << 'EOF'
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
      PORT: 5000,
      DATABASE_URL: 'postgresql://postgres@localhost:5432/servicedesk',
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
check_success "PM2 configuration" "pm2-config"

# Step 12: Start application
echo "Step 12: Starting application..."
mkdir -p logs

pm2 start ecosystem.config.js || handle_error "Failed to start application with PM2" "pm2-start"
pm2 save || handle_error "Failed to save PM2 configuration" "pm2-save"
check_success "Application start" "pm2-start"

# Step 13: Verify deployment
echo "Step 13: Verifying deployment..."
sleep 5

echo "PM2 Status:"
pm2 status

echo "Application logs (last 10 lines):"
pm2 logs servicedesk --lines 10

# Get server IP
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "localhost")

echo ""
echo "=== DEPLOYMENT COMPLETE ==="
echo ""
echo "Application Details:"
echo "  External URL: http://$SERVER_IP:$APP_PORT"
echo "  Local URL: http://localhost:$APP_PORT"
echo "  Admin Login: john.doe / password123"
echo ""
echo "Next Steps:"
echo "1. Access the application using the URLs above"
echo "2. Login with admin credentials"
echo "3. Navigate to Admin Console > Email Settings"
echo "4. Configure your SendGrid API key"
echo ""
echo "Management Commands:"
echo "  View logs: pm2 logs servicedesk"
echo "  Restart: pm2 restart servicedesk"
echo "  Stop: pm2 stop servicedesk"
echo "  Status: pm2 status"
echo ""
echo "Deployment completed successfully at $(date)"

# Keep session open
echo "Press Enter to finish..."
read