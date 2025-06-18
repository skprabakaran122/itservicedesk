#!/bin/bash

echo "Fixing PM2 with ES modules support..."

cd /var/www/servicedesk

# Create ES module compatible startup script
cat > server/start.mjs << 'EOF'
import { config } from 'dotenv';
import { spawn } from 'child_process';

// Load environment variables
config();

// Start the application with tsx
const child = spawn('tsx', ['server/index.ts'], {
  stdio: 'inherit',
  env: process.env
});

child.on('error', (error) => {
  console.error('Failed to start application:', error);
  process.exit(1);
});

child.on('exit', (code) => {
  console.log(`Application exited with code ${code}`);
  process.exit(code);
});
EOF

# Update PM2 config to use the .mjs file
cat > ecosystem.config.cjs << 'EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'node',
    args: 'server/start.mjs',
    cwd: '/var/www/servicedesk',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    error_file: '/var/log/servicedesk/error.log',
    out_file: '/var/log/servicedesk/out.log',
    log_file: '/var/log/servicedesk/combined.log',
    time: true
  }]
};
EOF

# Test the ES module approach
echo "Testing ES module startup script..."
timeout 5s node server/start.mjs &
TEST_PID=$!
sleep 3

if kill -0 $TEST_PID 2>/dev/null; then
    echo "✓ ES module approach works"
    kill $TEST_PID 2>/dev/null
    
    # Restart PM2 with new configuration
    echo "Restarting PM2 with ES module script..."
    pm2 delete servicedesk 2>/dev/null || true
    pm2 start ecosystem.config.cjs
    pm2 save
    
    # Wait and test
    sleep 10
    
    if curl -s http://localhost:3000 > /dev/null; then
        echo "✅ SUCCESS! Application is now responding"
        echo "Your IT Service Desk is accessible at: http://98.81.235.7"
        
        # Show sample response
        echo "Sample response:"
        curl -s http://localhost:3000 | head -3
    else
        echo "Still not responding. Trying direct dotenv in main file approach..."
        
        # Alternative: Update server/index.ts to load dotenv at the very top
        cp server/index.ts server/index.ts.backup.$(date +%s)
        
        # Add dotenv at the very beginning of server/index.ts
        if ! grep -q "import.*dotenv" server/index.ts; then
            echo "Adding dotenv to server/index.ts..."
            sed -i '1i import { config } from "dotenv";\nconfig();' server/index.ts
        fi
        
        # Simple PM2 config using tsx directly
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
    time: true
  }]
};
EOF
        
        pm2 delete servicedesk 2>/dev/null || true
        pm2 start ecosystem.config.cjs
        pm2 save
        
        sleep 10
        
        if curl -s http://localhost:3000 > /dev/null; then
            echo "✅ SUCCESS with direct dotenv approach!"
            echo "Your IT Service Desk is accessible at: http://98.81.235.7"
        else
            echo "❌ Still failing. Checking PM2 logs..."
            pm2 logs servicedesk --lines 20
            
            echo ""
            echo "Testing manual startup one more time..."
            export DATABASE_URL="postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk"
            export NODE_ENV="production" 
            export PORT="3000"
            tsx server/index.ts &
            MANUAL_PID=$!
            sleep 5
            
            if curl -s http://localhost:3000 > /dev/null; then
                echo "✓ Manual startup works - PM2 configuration issue"
                kill $MANUAL_PID 2>/dev/null
                
                # Try one more PM2 approach with explicit env vars
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
    node_args: '--experimental-loader tsx/esm'
  }]
};
EOF
                
                pm2 delete servicedesk 2>/dev/null || true
                pm2 start ecosystem.config.cjs
                pm2 save
                
                sleep 8
                curl -s http://localhost:3000 > /dev/null && echo "✅ Final approach succeeded!" || echo "❌ All approaches exhausted"
            else
                echo "❌ Manual startup also fails"
                kill $MANUAL_PID 2>/dev/null || true
            fi
        fi
    fi
else
    echo "ES module script failed. Checking error..."
fi

echo ""
echo "Final status:"
pm2 status
curl -s http://localhost:3000 > /dev/null && echo "✅ Application responding" || echo "❌ Application not responding"