# Fresh Server Deployment Guide

## Complete Application Reset on Ubuntu Server

### Step 1: Connect to Server
```bash
ssh your-username@54.160.177.174
```

### Step 2: Stop and Remove Current Application
```bash
# Stop PM2 process
pm2 stop servicedesk
pm2 delete servicedesk

# Remove existing application directory
sudo rm -rf /home/ubuntu/servicedesk

# Kill any remaining Node processes (if needed)
sudo pkill -f node
```

### Step 3: Fresh Clone from Git
```bash
# Navigate to home directory
cd /home/ubuntu

# Clone fresh copy from repository
git clone <your-git-repository-url> servicedesk

# Navigate to project directory
cd servicedesk
```

### Step 4: Install Dependencies and Build
```bash
# Install Node.js dependencies
npm install

# Build the client application
npm run build

# Move build files to expected location for production
mkdir -p server/public
cp -r dist/public/* server/public/ 2>/dev/null || true
```

### Step 5: Environment Configuration
```bash
# Create environment file
nano .env

# Add these environment variables:
NODE_ENV=production
DATABASE_URL=your_postgresql_connection_string
SENDGRID_API_KEY=your_sendgrid_api_key
PORT=5000
```

### Step 6: Database Setup
```bash
# Push database schema
npm run db:push
```

### Step 7: Start Application with PM2
```bash
# Create logs directory
mkdir -p logs

# Option 1: Use .cjs config file
pm2 start ecosystem.config.cjs

# Option 2: Direct PM2 start (if config issues persist)
pm2 start server/index.ts --name servicedesk --interpreter node --interpreter-args "--import tsx" --env production

# Save PM2 configuration
pm2 save

# Setup PM2 to start on system boot
pm2 startup
```

### Step 8: Verify Deployment
```bash
# Check PM2 status
pm2 status

# View application logs
pm2 logs servicedesk --lines 20

# Test application
curl http://localhost:5000
```

### Step 9: Configure Nginx (if needed)
```bash
# Edit Nginx configuration
sudo nano /etc/nginx/sites-available/default

# Add proxy configuration:
location / {
    proxy_pass http://localhost:5000;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_cache_bypass $http_upgrade;
}

# Restart Nginx
sudo systemctl restart nginx
```

### Step 10: Final Verification
1. Access application: http://54.160.177.174:5000
2. Login with: john.doe / password123
3. Test email settings in Admin Console
4. Verify all functionality works

## New Features in This Deployment

### Email Integration
- Complete SendGrid integration
- Dynamic email configuration
- Professional email templates
- Admin email settings interface
- Automatic notifications for tickets/changes

### Enhanced Admin Console
- Direct `/admin` URL access
- Email settings management
- API key configuration
- Test email functionality

### Improved User Experience
- Fixed modal scrolling
- Better error handling
- Enhanced routing
- Professional Calpion branding

## Post-Deployment Tasks

1. **Complete SendGrid Setup**:
   - Login to SendGrid dashboard
   - Verify sender identity for `noreply@calpion.com`
   - Or authenticate the `calpion.com` domain

2. **Test Email Functionality**:
   - Go to Admin Console > Email Settings
   - Configure SendGrid API key
   - Send test email to verify setup

3. **Configure User Accounts**:
   - Update user passwords if needed
   - Set up additional admin users
   - Configure department assignments

## Troubleshooting

### If Application Won't Start
```bash
# Check Node.js version
node --version

# Should be v20.x.x
# If not, update Node.js:
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs
```

### If Database Connection Fails
```bash
# Verify PostgreSQL connection
psql $DATABASE_URL

# Check environment variables
printenv | grep DATABASE_URL
```

### If Email Not Working
1. Check API key in Admin Console
2. Verify sender identity in SendGrid
3. Check application logs: `pm2 logs servicedesk`

This fresh deployment will give you the complete updated application with all email integration features working properly.