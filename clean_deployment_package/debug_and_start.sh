#!/bin/bash

echo "Debugging PM2 startup and fixing directly..."

cd /var/www/servicedesk

# Check what's in the current server/index.ts
echo "1. Checking server/index.ts for dotenv imports..."
head -10 server/index.ts

echo ""
echo "2. Checking if database connection works manually..."
export DATABASE_URL="postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk"
export NODE_ENV="production"
export PORT="3000"

# Test database connection directly
echo "Testing database connection..."
psql -h localhost -U servicedesk -d servicedesk -c "SELECT 1;" 2>/dev/null && echo "✓ Database connection works" || echo "❌ Database connection failed"

echo ""
echo "3. Testing application startup with verbose output..."
tsx server/index.ts &
APP_PID=$!
sleep 5

if kill -0 $APP_PID 2>/dev/null; then
    echo "✓ Application is running (PID: $APP_PID)"
    
    # Test if it responds
    if curl -s http://localhost:3000 > /dev/null; then
        echo "✅ Application responds to HTTP requests"
        kill $APP_PID
        
        # Now configure PM2 properly
        echo "4. Configuring PM2 with working settings..."
        
        # Create simple PM2 config with explicit environment
        cat > ecosystem.config.cjs << 'EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'tsx',
    args: 'server/index.ts',
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
    kill_timeout: 5000
  }]
};
EOF

        pm2 delete servicedesk 2>/dev/null || true
        pm2 start ecosystem.config.cjs
        pm2 save
        
        echo "5. Waiting for PM2 startup..."
        sleep 15
        
        if curl -s http://localhost:3000 > /dev/null; then
            echo "✅ SUCCESS! PM2 is now running the application"
            echo "Your IT Service Desk is accessible at: http://98.81.235.7"
            
            # Show sample response
            echo "Sample response:"
            curl -s http://localhost:3000 | head -3
        else
            echo "PM2 still not working. Checking logs..."
            echo "Error logs:"
            cat /var/log/servicedesk/error.log 2>/dev/null || echo "No error logs"
            echo "Output logs:"
            cat /var/log/servicedesk/out.log 2>/dev/null || echo "No output logs"
            
            echo ""
            echo "PM2 status:"
            pm2 status
            
            echo ""
            echo "Let's try running as a service instead..."
            
            # Create systemd service as fallback
            cat > /etc/systemd/system/servicedesk.service << 'EOF'
[Unit]
Description=IT Service Desk Application
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/var/www/servicedesk
Environment=NODE_ENV=production
Environment=PORT=3000
Environment=DATABASE_URL=postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk
ExecStart=/usr/bin/tsx server/index.ts
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=servicedesk

[Install]
WantedBy=multi-user.target
EOF

            systemctl daemon-reload
            systemctl enable servicedesk
            systemctl start servicedesk
            
            sleep 8
            
            if curl -s http://localhost:3000 > /dev/null; then
                echo "✅ SUCCESS with systemd service!"
                echo "Your IT Service Desk is accessible at: http://98.81.235.7"
                systemctl status servicedesk
            else
                echo "❌ Systemd service also failed"
                journalctl -u servicedesk --lines=20
            fi
        fi
    else
        echo "❌ Application doesn't respond to HTTP requests"
        kill $APP_PID 2>/dev/null
        
        echo "Checking what's happening..."
        tsx server/index.ts 2>&1 | head -20
    fi
else
    echo "❌ Application failed to start"
    
    echo "Checking for errors..."
    tsx server/index.ts 2>&1 | head -20
fi

echo ""
echo "Final status check:"
curl -s http://localhost:3000 > /dev/null && echo "✅ Application is responding" || echo "❌ Application is not responding"