# Production Server Fix Commands

## Issue Analysis
From the logs, I can see:
- SendGrid API key format error ("API key does not start with 'SG.'")
- IP address not whitelisted with SendGrid
- Application needs Department/Business Unit schema updates

## Step 1: Connect to Production Server
```bash
ssh ubuntu@54.160.177.174
cd /home/ubuntu/servicedesk
```

## Step 2: Fix SendGrid Configuration
```bash
# Check current environment
pm2 env servicedesk

# Stop the application temporarily
pm2 stop servicedesk

# Create/update .env file with proper SendGrid key
cat > .env << 'EOL'
NODE_ENV=production
DATABASE_URL=your_database_url_here
SENDGRID_API_KEY=SG.your_actual_sendgrid_api_key_here
SESSION_SECRET=your_session_secret_here
EOL

# Set proper file permissions
chmod 600 .env
```

## Step 3: Update Application Code
```bash
# Pull latest changes with Department/Business Unit fields
git pull origin main

# Install any new dependencies
npm install

# Update database schema
npx drizzle-kit push
```

## Step 4: Update PM2 Configuration
```bash
# Update ecosystem.config.js to use .env file
cat > ecosystem.config.js << 'EOL'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'npm',
    args: 'run dev',
    cwd: '/home/ubuntu/servicedesk',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env_file: '.env',
    env: {
      NODE_ENV: 'production',
      PORT: 5000
    },
    error_file: './logs/pm2-error.log',
    out_file: './logs/pm2-out.log',
    log_file: './logs/pm2-combined.log',
    time: true
  }]
};
EOL
```

## Step 5: Restart Application
```bash
# Delete existing PM2 process
pm2 delete servicedesk

# Start with new configuration
pm2 start ecosystem.config.js

# Save PM2 configuration
pm2 save

# Check status
pm2 status
pm2 logs servicedesk --lines 20
```

## Step 6: Verify Deployment
```bash
# Test basic endpoint
curl -s http://localhost:5000/api/products

# Test authentication endpoint
curl -s http://localhost:5000/api/auth/me

# Check if Department/Business Unit fields are working
curl -s "http://localhost:5000/api/tickets" | grep -i "department\|business"
```

## Step 7: SendGrid IP Whitelisting
You need to whitelist the server IP (54.160.177.174) in your SendGrid account:

1. Login to SendGrid dashboard
2. Go to Settings > API Keys
3. Edit your API key
4. Add IP Address: 54.160.177.174
5. Save changes

## Step 8: Final Verification
```bash
# Check application logs for SendGrid success
pm2 logs servicedesk --lines 10

# Test external access
curl -s http://54.160.177.174:5000/
```

## Expected Results After Fix
- SendGrid API key properly formatted and authenticated
- Server IP whitelisted for email sending
- Department and Business Unit fields available in ticket creation
- Application accessible at http://54.160.177.174:5000
- No API key format errors in logs

## If Issues Persist
1. Check firewall: `sudo ufw status`
2. Verify port 5000 is open: `sudo netstat -tlnp | grep 5000`
3. Check nginx configuration if using reverse proxy
4. Verify database connectivity: `npm run db:check` (if available)

Execute these commands in order to resolve the production issues and deploy the Department/Business Unit features.