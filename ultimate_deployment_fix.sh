#!/bin/bash

echo "Ultimate deployment fix - comprehensive solution..."

cd /var/www/servicedesk

# Step 1: Verify all prerequisites
echo "1. Verifying system prerequisites..."
node --version
npm --version
tsx --version 2>/dev/null || echo "tsx not found globally, checking local..."
npx tsx --version

# Step 2: Check and fix package.json if needed
echo "2. Checking package.json configuration..."
if grep -q '"type": "module"' package.json; then
    echo "ES modules detected - ensuring proper configuration"
    
    # Ensure dotenv is properly imported at the start of server/index.ts
    if ! grep -q "import.*dotenv" server/index.ts; then
        echo "Adding dotenv import to server/index.ts..."
        cp server/index.ts server/index.ts.backup.$(date +%s)
        sed -i '1i import { config } from "dotenv";\nconfig();' server/index.ts
    fi
else
    echo "CommonJS modules detected"
fi

# Step 3: Test database connection
echo "3. Testing database connection..."
export DATABASE_URL="postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk"
export NODE_ENV="production"
export PORT="3000"

if psql -h localhost -U servicedesk -d servicedesk -c "SELECT 1;" 2>/dev/null; then
    echo "✓ Database connection successful"
else
    echo "❌ Database connection failed - fixing..."
    sudo -u postgres psql -c "ALTER USER servicedesk PASSWORD 'servicedesk123';"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE servicedesk TO servicedesk;"
fi

# Step 4: Test application startup with full debugging
echo "4. Testing application startup..."
timeout 15s tsx server/index.ts 2>&1 &
APP_PID=$!
sleep 8

if kill -0 $APP_PID 2>/dev/null; then
    echo "✓ Application started successfully"
    
    # Test HTTP response
    if curl -s http://localhost:3000 > /dev/null; then
        echo "✅ Application responds to HTTP requests"
        kill $APP_PID 2>/dev/null
        
        # Proceed with PM2 setup
        echo "5. Setting up PM2 with proven configuration..."
        
        # Kill any existing PM2 processes
        pm2 delete all 2>/dev/null || true
        pm2 kill 2>/dev/null || true
        
        # Create working PM2 configuration
        cat > ecosystem.config.cjs << 'EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'npx',
    args: 'tsx server/index.ts',
    cwd: '/var/www/servicedesk',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production',
      PORT: 3000,
      DATABASE_URL: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk'
    },
    error_file: '/var/log/servicedesk/error.log',
    out_file: '/var/log/servicedesk/out.log',
    log_file: '/var/log/servicedesk/combined.log',
    time: true,
    kill_timeout: 10000,
    wait_ready: true,
    listen_timeout: 10000
  }]
};
EOF
        
        # Start PM2
        pm2 start ecosystem.config.cjs
        pm2 save
        pm2 startup ubuntu -u ubuntu --hp /home/ubuntu
        
        # Wait for startup
        echo "Waiting for PM2 startup..."
        sleep 20
        
        # Test PM2 response
        if curl -s http://localhost:3000 > /dev/null; then
            echo "✅ SUCCESS! PM2 is running the application"
            echo "Your IT Service Desk is accessible at: http://98.81.235.7"
            pm2 status
        else
            echo "PM2 approach failed, trying systemd service..."
            
            # Create systemd service
            sudo tee /etc/systemd/system/servicedesk.service > /dev/null << 'EOF'
[Unit]
Description=IT Service Desk Application
After=network.target postgresql.service

[Service]
Type=simple
User=ubuntu
Group=ubuntu
WorkingDirectory=/var/www/servicedesk
Environment=NODE_ENV=production
Environment=PORT=3000
Environment=DATABASE_URL=postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk
ExecStart=/usr/bin/npx tsx server/index.ts
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=servicedesk

[Install]
WantedBy=multi-user.target
EOF

            # Stop PM2 and start systemd service
            pm2 delete all 2>/dev/null || true
            sudo systemctl daemon-reload
            sudo systemctl enable servicedesk
            sudo systemctl start servicedesk
            
            sleep 15
            
            if curl -s http://localhost:3000 > /dev/null; then
                echo "✅ SUCCESS with systemd service!"
                echo "Your IT Service Desk is accessible at: http://98.81.235.7"
                sudo systemctl status servicedesk
            else
                echo "❌ Both PM2 and systemd failed"
                echo "Checking systemd logs..."
                sudo journalctl -u servicedesk --lines=30
            fi
        fi
    else
        echo "❌ Application doesn't respond to HTTP"
        kill $APP_PID 2>/dev/null
        echo "Checking startup errors..."
        tsx server/index.ts 2>&1 | head -30
    fi
else
    echo "❌ Application failed to start"
    echo "Checking errors..."
    tsx server/index.ts 2>&1 | head -30
    
    # Try installing dependencies again
    echo "Reinstalling dependencies..."
    npm install --production
    npm run build 2>/dev/null || echo "Build step not needed"
    
    echo "Retrying startup..."
    timeout 10s tsx server/index.ts 2>&1
fi

# Step 6: Final verification and nginx check
echo "6. Final verification..."
if curl -s http://localhost:3000 > /dev/null; then
    echo "✅ Application is running on port 3000"
    
    # Check nginx configuration
    if nginx -t 2>/dev/null; then
        echo "✓ Nginx configuration is valid"
        sudo systemctl reload nginx
        echo "✅ Complete deployment successful!"
        echo "Access your IT Service Desk at: http://98.81.235.7"
    else
        echo "❌ Nginx configuration has issues"
        sudo nginx -t
    fi
else
    echo "❌ Application is still not responding"
    echo "Manual troubleshooting required"
fi

echo ""
echo "=== DEPLOYMENT STATUS ==="
echo "Node.js: $(node --version)"
echo "Database: $(psql -h localhost -U servicedesk -d servicedesk -c 'SELECT 1;' 2>/dev/null && echo 'Connected' || echo 'Failed')"
echo "Application: $(curl -s http://localhost:3000 > /dev/null && echo 'Running' || echo 'Not responding')"
echo "Nginx: $(nginx -t 2>/dev/null && echo 'OK' || echo 'Error')"