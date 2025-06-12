#!/bin/bash

# Unix Socket Database Fix - Bypasses SCRAM authentication completely
echo "Fixing database connection using Unix sockets..."

# Stop application
pm2 delete servicedesk 2>/dev/null || true

cd /home/ubuntu/servicedesk

# Use Unix socket connection to completely bypass authentication
cat > .env << 'EOF'
NODE_ENV=production
PORT=5000
DATABASE_URL=postgresql:///servicedesk?host=/var/run/postgresql
SENDGRID_API_KEY=configure_in_admin_console
EOF

# Update PM2 configuration to use Unix socket
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
      DATABASE_URL: 'postgresql:///servicedesk?host=/var/run/postgresql',
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

# Test Unix socket connection
echo "Testing Unix socket connection..."
export DATABASE_URL="postgresql:///servicedesk?host=/var/run/postgresql"

if psql "$DATABASE_URL" -c "SELECT 'Unix socket connection successful';" 2>/dev/null; then
    echo "Unix socket connection working"
    
    # Setup database schema
    npm run db:push
    
    # Start application
    pm2 start ecosystem.config.js
    pm2 save
    
    echo "Application started with Unix socket connection"
    sleep 3
    pm2 logs servicedesk --lines 5
else
    echo "Unix socket failed, trying peer authentication..."
    
    # Alternative: peer authentication
    export DATABASE_URL="postgresql:///servicedesk"
    cat > .env << 'EOF'
NODE_ENV=production
PORT=5000
DATABASE_URL=postgresql:///servicedesk
SENDGRID_API_KEY=configure_in_admin_console
EOF
    
    npm run db:push
    pm2 start ecosystem.config.js
    pm2 save
fi