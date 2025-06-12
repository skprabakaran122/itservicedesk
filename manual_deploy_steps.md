# Manual Deployment Steps - Run One by One

To avoid PuTTY disconnection, run these commands step by step:

## Step 1: Clean existing installation
```bash
pm2 stop all 2>/dev/null || true
pm2 delete all 2>/dev/null || true
sudo rm -rf /home/ubuntu/servicedesk 2>/dev/null || true
```

## Step 2: Install system dependencies
```bash
sudo apt update
sudo apt install -y postgresql postgresql-contrib curl git
sudo systemctl enable postgresql
sudo systemctl start postgresql
```

## Step 3: Install Node.js 20
```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs
sudo npm install -g pm2 tsx typescript
```

## Step 4: Setup PostgreSQL database
```bash
sudo -u postgres psql << 'EOF'
DROP DATABASE IF EXISTS servicedesk;
CREATE DATABASE servicedesk;
\q
EOF
```

## Step 5: Clone application
```bash
cd /home/ubuntu
git clone https://github.com/skprabakaran122/itservicedesk.git servicedesk
cd servicedesk
```

## Step 6: Install dependencies
```bash
npm install
```

## Step 7: Create environment file
```bash
cat > .env << 'EOF'
NODE_ENV=production
PORT=5000
DATABASE_URL=postgresql://postgres@localhost:5432/servicedesk
SENDGRID_API_KEY=configure_in_admin_console
EOF
```

## Step 8: Setup database schema
```bash
export DATABASE_URL="postgresql://postgres@localhost:5432/servicedesk"
npm run db:push
```

## Step 9: Create PM2 config
```bash
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
```

## Step 10: Start application
```bash
mkdir -p logs
pm2 start ecosystem.config.js
pm2 save
pm2 status
```

## Step 11: Verify deployment
```bash
pm2 logs servicedesk --lines 10
curl -I http://localhost:5000
```

Run each step and wait for completion before proceeding to the next one. This prevents the script from exiting your PuTTY session.