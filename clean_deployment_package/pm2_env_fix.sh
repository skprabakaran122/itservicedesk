#!/bin/bash

echo "Fixing PM2 environment variable loading..."

cd /var/www/servicedesk

# Create a startup script that explicitly loads environment
cat > start_with_env.sh << 'EOF'
#!/bin/bash
cd /var/www/servicedesk
export $(cat .env | xargs)
exec tsx server/index.ts
EOF

chmod +x start_with_env.sh

# Update PM2 config to use the startup script
cat > ecosystem.config.cjs << 'EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: './start_with_env.sh',
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

# Alternative: Create a node script that loads dotenv first
cat > server/start.js << 'EOF'
require('dotenv').config();
require('tsx/cli').main(['server/index.ts']);
EOF

# Update PM2 config to use the node script instead
cat > ecosystem.config.cjs << 'EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'node',
    args: 'server/start.js',
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

# Test the node script approach
echo "Testing node script approach..."
timeout 5s node server/start.js &
TEST_PID=$!
sleep 2

if kill -0 $TEST_PID 2>/dev/null; then
    echo "✓ Node script approach works"
    kill $TEST_PID 2>/dev/null
    
    # Restart PM2 with new configuration
    echo "Restarting PM2 with node script..."
    pm2 delete servicedesk 2>/dev/null || true
    pm2 start ecosystem.config.cjs
    pm2 save
    
    # Wait and test
    sleep 8
    
    if curl -s http://localhost:3000 > /dev/null; then
        echo "✅ SUCCESS! Application is now responding"
        echo "Your IT Service Desk is accessible at: http://98.81.235.7"
        curl -s http://localhost:3000 | head -3
    else
        echo "Still not responding. Trying bash script approach..."
        
        # Fall back to bash script
        cat > ecosystem.config.cjs << 'EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: './start_with_env.sh',
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
        
        pm2 delete servicedesk 2>/dev/null || true
        pm2 start ecosystem.config.cjs
        pm2 save
        
        sleep 8
        
        if curl -s http://localhost:3000 > /dev/null; then
            echo "✅ SUCCESS with bash script approach!"
            echo "Your IT Service Desk is accessible at: http://98.81.235.7"
        else
            echo "❌ Both approaches failed. Checking what's happening..."
            pm2 logs servicedesk --lines 20
        fi
    fi
else
    echo "Node script failed. Checking manual startup..."
    export DATABASE_URL="postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk"
    export NODE_ENV="production"
    export PORT="3000"
    
    echo "Manual test with explicit exports:"
    timeout 10s tsx server/index.ts &
    MANUAL_PID=$!
    sleep 3
    
    if curl -s http://localhost:3000 > /dev/null; then
        echo "✓ Manual startup works"
        kill $MANUAL_PID 2>/dev/null
    else
        echo "❌ Even manual startup fails"
        kill $MANUAL_PID 2>/dev/null || true
    fi
fi

echo ""
pm2 status