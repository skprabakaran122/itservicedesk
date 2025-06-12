#!/bin/bash

# Fix PostgreSQL Authentication Issues
echo "Fixing PostgreSQL authentication..."

# Stop application
pm2 stop servicedesk 2>/dev/null || true

# Fix PostgreSQL authentication method
echo "Updating PostgreSQL authentication configuration..."

# Get PostgreSQL version
PG_VERSION=$(sudo -u postgres psql -t -c "SELECT version();" | grep -oP '\d+\.\d+' | head -1)
PG_CONFIG_DIR="/etc/postgresql/$PG_VERSION/main"

# Backup current config
sudo cp "$PG_CONFIG_DIR/pg_hba.conf" "$PG_CONFIG_DIR/pg_hba.conf.backup" 2>/dev/null || true

# Create simplified pg_hba.conf for local development
sudo tee "$PG_CONFIG_DIR/pg_hba.conf" > /dev/null << 'EOF'
# PostgreSQL Client Authentication Configuration File
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# "local" is for Unix domain socket connections only
local   all             postgres                                trust
local   all             all                                     trust

# IPv4 local connections:
host    all             all             127.0.0.1/32            trust
host    all             all             localhost               trust

# IPv6 local connections:
host    all             all             ::1/128                 trust
EOF

# Restart PostgreSQL
sudo systemctl restart postgresql
sleep 3

# Recreate database with trust authentication
echo "Recreating database..."
sudo -u postgres psql << 'EOF'
DROP DATABASE IF EXISTS servicedesk;
CREATE DATABASE servicedesk;
\q
EOF

# Navigate to project directory
cd /home/ubuntu/servicedesk

# Update DATABASE_URL to use trust authentication
cat > .env << 'EOF'
NODE_ENV=production
PORT=5000
DATABASE_URL=postgresql://postgres@localhost/servicedesk
SENDGRID_API_KEY=configure_in_admin_console
EOF

# Test database connection
echo "Testing database connection..."
export DATABASE_URL="postgresql://postgres@localhost/servicedesk"

if psql "$DATABASE_URL" -c "SELECT 'Connection successful';" > /dev/null 2>&1; then
    echo "Database connection successful"
    
    # Setup database schema
    echo "Setting up database schema..."
    npm run db:push
    
    if [ $? -eq 0 ]; then
        echo "Database schema created successfully"
        
        # Update PM2 configuration
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
      DATABASE_URL: 'postgresql://postgres@localhost/servicedesk',
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
        
        # Restart application
        echo "Starting application..."
        pm2 restart servicedesk || pm2 start ecosystem.config.js
        pm2 save
        
        echo "Application started successfully!"
        pm2 logs servicedesk --lines 5
    else
        echo "Database schema setup failed"
    fi
else
    echo "Database connection failed"
fi