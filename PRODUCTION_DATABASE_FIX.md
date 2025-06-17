# Production Database Connection Fix

## Issue
Production server experiencing connection timeouts to PostgreSQL database at 98.81.235.7:5432

## Root Cause Analysis
The error `ETIMEDOUT 98.81.235.7:5432` indicates network connectivity issues between your Ubuntu server and the PostgreSQL database.

## Solution Steps

### 1. Run Database Connection Fix Script
```bash
cd /var/www/servicedesk
chmod +x fix_production_database.sh
sudo ./fix_production_database.sh
```

### 2. Check Server IP Whitelisting
Your server's public IP needs to be whitelisted in your database provider's firewall:

```bash
# Get your server's public IP
curl -s ifconfig.me
```

**Action Required:** Add this IP to your database provider's allowed connections list.

### 3. Verify Database URL Format
Check your DATABASE_URL in `/var/www/servicedesk/.env`:

```bash
# Should look like:
DATABASE_URL=postgresql://username:password@98.81.235.7:5432/database_name?sslmode=require
```

### 4. Test Direct Connection
```bash
cd /var/www/servicedesk
source .env
psql "$DATABASE_URL" -c "SELECT 1;"
```

### 5. Deploy Updated Code with Enhanced Connection Handling
The updated code includes:
- Extended connection timeouts (15 seconds)
- Reduced connection pool size to avoid overwhelming remote database
- Enhanced SSL configuration for cloud databases
- Better error handling and retry logic

### 6. Alternative: Use Local PostgreSQL
If remote connection continues failing, install local PostgreSQL:

```bash
sudo apt update
sudo apt install -y postgresql postgresql-contrib
sudo -u postgres createuser --interactive servicedesk
sudo -u postgres createdb servicedesk
```

Then update .env:
```
DATABASE_URL=postgresql://servicedesk:password@localhost:5432/servicedesk
```

## Common Solutions by Database Provider

### For Neon Database
1. Go to Neon Console → Settings → IP Allow
2. Add your server IP: `curl -s ifconfig.me`
3. Ensure connection string uses SSL: `?sslmode=require`

### For AWS RDS
1. Security Groups → Edit inbound rules
2. Add rule: PostgreSQL (5432) from your server IP

### For DigitalOcean Managed Database
1. Database → Settings → Trusted Sources
2. Add your server's public IP address

## Deployment Command
Once database connectivity is resolved:

```bash
cd /var/www/servicedesk
sudo systemctl stop servicedesk.service
sudo -u www-data git pull origin main
sudo -u www-data npm run db:push
sudo -u www-data npm run build
sudo -u www-data cp -r dist/* server/public/
sudo systemctl start servicedesk.service
sudo systemctl status servicedesk.service
```

## Monitoring
Check logs for connection status:
```bash
sudo journalctl -u servicedesk.service -f
```

The enhanced database configuration will automatically handle connection retries and provide better error reporting.