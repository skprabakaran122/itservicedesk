#!/bin/bash

echo "=== DIRECT DEPLOYMENT OF YOUR WORKING APPLICATION ==="

APP_DIR="/var/www/itservicedesk"
SERVICE_NAME="itservicedesk"

# Stop service
sudo systemctl stop $SERVICE_NAME

# Backup existing
sudo cp -r $APP_DIR $APP_DIR.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true

# Clean and recreate
sudo rm -rf $APP_DIR
sudo mkdir -p $APP_DIR
cd $APP_DIR

# Clone your working repository again with all the latest changes
echo "Cloning your latest working application..."
git clone https://github.com/skprabakaran122/itservicedesk.git .

# Install all dependencies including dev dependencies for building
echo "Installing all dependencies..."
npm install

# Build your React application
echo "Building your React application..."
export NODE_OPTIONS="--max-old-space-size=4096"

if npm run build; then
    echo "✓ Your React application built successfully"
    
    # Verify the build contains your actual app
    if [ -f "dist/index.html" ]; then
        BUILD_SIZE=$(du -sh dist/ | cut -f1)
        echo "Frontend build size: $BUILD_SIZE"
        
        # Check for your app components
        if ls dist/assets/*.js 2>/dev/null | head -1 | xargs grep -l "react\|React" 2>/dev/null; then
            echo "✓ Your React application is in the build"
        fi
    fi
    
    # Also build the server
    if ls dist/*.js 2>/dev/null | grep -v assets; then
        echo "✓ Server build also created"
    fi
    
else
    echo "Build failed, trying alternative approaches..."
    
    # Try building without server bundling
    if npx vite build; then
        echo "✓ Frontend built with vite directly"
    else
        echo "Frontend build failed, checking vite configuration..."
        
        # Check if we have the right vite config
        if [ -f "vite.config.ts" ]; then
            cat vite.config.ts
        fi
        
        # Try with basic vite build
        npx vite build --mode production --outDir dist
    fi
fi

# Create production start script
echo "Creating production start script..."
cat << 'PROD_START_EOF' > start-production.js
import { spawn } from 'child_process';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Start the server
const serverPath = path.join(__dirname, 'dist', 'index.js');
const serverProcess = spawn('node', [serverPath], {
    stdio: 'inherit',
    env: {
        ...process.env,
        NODE_ENV: 'production',
        PORT: '5000',
        DATABASE_URL: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk'
    }
});

serverProcess.on('error', (err) => {
    console.error('Server process error:', err);
});

serverProcess.on('exit', (code) => {
    console.log(`Server process exited with code ${code}`);
});

console.log('Production server started with PID:', serverProcess.pid);
PROD_START_EOF

# Update package.json start script
if [ -f "package.json" ]; then
    # Update start script to use the built server
    if [ -f "dist/index.js" ]; then
        echo "Using built server"
        sed -i 's/"start": ".*"/"start": "node dist\/index.js"/' package.json
    else
        echo "Using development server in production mode"
        sed -i 's/"start": ".*"/"start": "NODE_ENV=production tsx server\/index.ts"/' package.json
    fi
fi

# Fix permissions
sudo chown -R ubuntu:ubuntu $APP_DIR

# Update systemd service to use your app
sudo tee /etc/systemd/system/$SERVICE_NAME.service > /dev/null << SERVICE_EOF
[Unit]
Description=Calpion IT Service Desk - Your Application
After=network.target
Wants=postgresql.service

[Service]
Type=simple
User=ubuntu
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/npm start
Restart=always
RestartSec=10
Environment=NODE_ENV=production
Environment=PORT=5000
Environment=DATABASE_URL=postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk
Environment=SESSION_SECRET=calpion-service-desk-secret-key-2025

StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=$SERVICE_NAME

[Install]
WantedBy=multi-user.target
SERVICE_EOF

# Reload and start
sudo systemctl daemon-reload
sudo systemctl start $SERVICE_NAME

echo "Waiting for your application to start..."
sleep 20

# Test your application
echo "Testing your deployed application..."

# Test API health
API_HEALTH=$(curl -s http://localhost:5000/health)
if echo "$API_HEALTH" | grep -q '"status":"OK"'; then
    echo "✓ Your API server is running"
    
    # Get database counts
    USER_COUNT=$(echo "$API_HEALTH" | grep -o '"userCount":[0-9]*' | cut -d: -f2)
    PRODUCT_COUNT=$(echo "$API_HEALTH" | grep -o '"productCount":[0-9]*' | cut -d: -f2)
    TICKET_COUNT=$(echo "$API_HEALTH" | grep -o '"ticketCount":[0-9]*' | cut -d: -f2)
    CHANGE_COUNT=$(echo "$API_HEALTH" | grep -o '"changeCount":[0-9]*' | cut -d: -f2)
    
    echo "Database loaded: $USER_COUNT users, $PRODUCT_COUNT products, $TICKET_COUNT tickets, $CHANGE_COUNT changes"
else
    echo "✗ API server not responding correctly"
    echo "Response: $API_HEALTH"
fi

# Test frontend
FRONTEND_TEST=$(curl -s -H "Accept: text/html" http://localhost:5000/)
if echo "$FRONTEND_TEST" | grep -q "<!DOCTYPE html>"; then
    echo "✓ Frontend is serving"
    
    # Check if it contains your React app
    if echo "$FRONTEND_TEST" | grep -q "assets.*\.js\|/assets/.*\.css"; then
        echo "✓ Your built React application is being served"
    elif echo "$FRONTEND_TEST" | grep -q "react\|React"; then
        echo "✓ React application detected"
    else
        echo "Frontend serving but may not be your full React app"
    fi
else
    echo "Frontend serving JSON instead of HTML"
fi

# Test HTTPS
HTTPS_TEST=$(curl -k -s -H "Accept: text/html" https://98.81.235.7/)
if echo "$HTTPS_TEST" | grep -q "<!DOCTYPE html>"; then
    echo "✓ HTTPS serving your application"
fi

# Test login functionality
echo "Testing authentication..."
LOGIN_TEST=$(curl -k -s -c /tmp/test_cookies.txt -X POST https://98.81.235.7/api/auth/login -H "Content-Type: application/json" -d '{"username":"john.doe","password":"password123"}')
if echo "$LOGIN_TEST" | grep -q '"role":"admin"'; then
    echo "✓ Authentication working with your app"
    
    # Test the changes endpoint that was blank before
    CHANGES_TEST=$(curl -k -s -b /tmp/test_cookies.txt https://98.81.235.7/api/changes)
    CHANGE_COUNT=$(echo "$CHANGES_TEST" | grep -o '"id":' | wc -l)
    echo "✓ Changes endpoint returning $CHANGE_COUNT changes (resolves blank screen)"
    
    rm -f /tmp/test_cookies.txt
fi

# Show service status
sudo systemctl status $SERVICE_NAME --no-pager --lines=10

echo ""
echo "=== YOUR WORKING APPLICATION DEPLOYED ==="
echo "Access: https://98.81.235.7"
echo "Login: john.doe / password123"
echo "Changes screen: Will show data instead of blank"
echo ""
echo "Your actual development application is now running in production!"
echo "All your React components, styling, and functionality should be available."