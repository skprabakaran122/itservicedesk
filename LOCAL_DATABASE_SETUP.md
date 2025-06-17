# Local PostgreSQL Database Setup Guide

## Complete Fix for Local Database Connection

Your server has PostgreSQL installed locally but it's not properly configured. Here's the complete fix:

### Step 1: Run the PostgreSQL Setup Script
```bash
cd /var/www/servicedesk
chmod +x fix_local_postgresql.sh
sudo ./fix_local_postgresql.sh
```

This script will:
- Start and enable PostgreSQL service
- Configure PostgreSQL to accept local connections
- Create servicedesk database and user
- Update authentication settings
- Test the connection
- Update your .env file with correct local DATABASE_URL

### Step 2: Deploy Updated Code
```bash
cd /var/www/servicedesk
sudo systemctl stop servicedesk.service
sudo -u www-data git pull origin main
sudo -u www-data npm run db:push
sudo -u www-data npm run build
sudo -u www-data cp -r dist/* server/public/
sudo systemctl start servicedesk.service
```

### Step 3: Verify Everything Works
```bash
sudo systemctl status servicedesk.service
sudo journalctl -u servicedesk.service -f
```

## What Gets Fixed

### Database Configuration
- **Before**: DATABASE_URL pointing to remote/cloud database
- **After**: DATABASE_URL=postgresql://servicedesk:servicedesk_password_2024@localhost:5432/servicedesk

### PostgreSQL Service
- Service started and enabled for auto-start
- Configured to listen on localhost
- Authentication rules added for servicedesk user

### Application Configuration
- SSL disabled for local connections
- Connection timeouts optimized for local database
- Connection pool sized appropriately for local use

## Expected Results
After running the fix:
- PostgreSQL running on port 5432
- Database connection successful
- Application starts without timeout errors
- All features working with local database storage

## Troubleshooting
If issues persist after running the script:

1. **Check PostgreSQL status:**
   ```bash
   sudo systemctl status postgresql
   ```

2. **Test direct connection:**
   ```bash
   psql -h localhost -U servicedesk -d servicedesk
   ```

3. **View PostgreSQL logs:**
   ```bash
   sudo tail -f /var/log/postgresql/postgresql-*.log
   ```

4. **Check application logs:**
   ```bash
   sudo journalctl -u servicedesk.service -f
   ```