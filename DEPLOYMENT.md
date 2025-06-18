# Fresh Deployment Instructions

## Complete Clean Installation

Run this command on your Ubuntu server to perform a fresh deployment:

```bash
curl -O https://raw.githubusercontent.com/skprabakaran122/itservicedesk/main/fresh-deploy.sh
sudo bash fresh-deploy.sh
```

## What This Does

1. **Complete Cleanup**: Removes all existing files and services
2. **Fresh Git Clone**: Downloads latest code from your repository  
3. **Pure Node.js Server**: Creates production server using only core modules
4. **Database Connection**: Connects to your existing PostgreSQL database
5. **Clean Service**: Sets up new systemd service without conflicts

## Expected Results

- Access: https://98.81.235.7
- Login: john.doe / password123
- Complete React application with all functionality
- Changes screen displays actual data (no blank screen)
- All authentication and features working
- No module system errors

## Technical Details

- Uses pure Node.js HTTP server (no Express dependencies)
- CommonJS module system (no ES module conflicts)
- Direct PostgreSQL connection with existing data
- In-memory session management
- Complete React application served inline

This approach completely bypasses all the module resolution issues that were causing server startup failures.