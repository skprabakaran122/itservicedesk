# Simple Server Deployment Instructions

## What You Need

1. Download these files from this project:
   - `servicedesk-deployment.tar.gz` (the application)
   - `simple_deploy.sh` (the setup script)

## Steps to Deploy

### 1. Upload Files to Your Server
```bash
# Copy files to your server (using your preferred method)
# - WinSCP, FileZilla, or scp command
# - Upload both files to /home/ubuntu/
```

### 2. Login to Your Server
```bash
ssh ubuntu@YOUR_SERVER_IP
```

### 3. Run the Setup Script
```bash
chmod +x simple_deploy.sh
./simple_deploy.sh
```
The script will ask for a database password - create one and remember it.

### 4. Deploy the Application
```bash
# Go to the application directory
cd /home/ubuntu/servicedesk

# Extract the application files
tar -xzf /home/ubuntu/servicedesk-deployment.tar.gz

# Install dependencies
npm ci --only=production

# Build the application
npm run build

# Setup the database
npm run db:push

# Start the application
pm2 start ecosystem.config.cjs --env production
pm2 save
pm2 startup
```

### 5. Access Your Application
- **HTTPS:** https://YOUR_SERVER_IP:5001
- **HTTP:** http://YOUR_SERVER_IP:5000 (redirects to HTTPS)

## Optional: Add Email (SendGrid)
```bash
cd /home/ubuntu/servicedesk
nano .env
# Add your SendGrid API key: SENDGRID_API_KEY=your_key_here
pm2 restart calpion-service-desk
```

## Monitor Your Application
```bash
pm2 status          # Check if running
pm2 logs            # View logs
pm2 restart all     # Restart if needed
```

That's it! Your IT Service Desk will be running with HTTPS security, database persistence, and all features enabled.