# Server Environment Configuration Fix

## Issue
Your production server is missing required environment variables:
- `DATABASE_URL` - PostgreSQL connection string
- `SENDGRID_API_KEY` - Email service API key

## Quick Fix Commands

Run these commands on your Ubuntu server:

### 1. Stop the application
```bash
pm2 stop servicedesk
```

### 2. Create environment file
```bash
cd /home/ubuntu/servicedesk
nano .env
```

### 3. Add these variables to .env file:
```
NODE_ENV=production
PORT=5000
DATABASE_URL=your_postgresql_connection_string
SENDGRID_API_KEY=your_sendgrid_api_key
```

### 4. Set PM2 environment variables
```bash
# Set environment variables for PM2
pm2 set servicedesk:NODE_ENV production
pm2 set servicedesk:PORT 5000
pm2 set servicedesk:DATABASE_URL "your_postgresql_connection_string"
pm2 set servicedesk:SENDGRID_API_KEY "your_sendgrid_api_key"
```

### 5. Restart application
```bash
pm2 restart servicedesk
pm2 save
```

### 6. Alternative - Start with environment variables
```bash
# Delete existing process
pm2 delete servicedesk

# Start with explicit environment variables
pm2 start npm \
    --name servicedesk \
    -- run dev \
    --env NODE_ENV=production \
    --env PORT=5000 \
    --env DATABASE_URL="your_postgresql_connection_string" \
    --env SENDGRID_API_KEY="your_sendgrid_api_key"

pm2 save
```

### 7. Verify configuration
```bash
pm2 logs servicedesk --lines 10
pm2 env servicedesk
```

## Environment Variable Values

### DATABASE_URL
Format: `postgresql://username:password@host:port/database`
Example: `postgresql://user:pass@localhost:5432/servicedesk`

### SENDGRID_API_KEY
Format: `SG.xxxxxxxxxxxxxxxxxx.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`
- Get from your SendGrid dashboard
- Starts with "SG."

## Verification

After setting environment variables, you should see:
- No "DATABASE_URL must be set" errors
- No "SENDGRID_API_KEY not configured" messages
- Application starts successfully on port 5000
- Database connection established

## Troubleshooting

If still having issues:

1. **Check environment variables are loaded:**
   ```bash
   pm2 show servicedesk
   ```

2. **View detailed logs:**
   ```bash
   pm2 logs servicedesk --lines 20
   ```

3. **Restart PM2 daemon:**
   ```bash
   pm2 kill
   pm2 resurrect
   ```

4. **Test database connection manually:**
   ```bash
   psql "$DATABASE_URL"
   ```

Your application will be fully functional once these environment variables are properly configured.