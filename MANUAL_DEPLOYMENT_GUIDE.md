# Manual Deployment Guide - Department and Business Unit Fields

## Step 1: Git Sync (Execute from your terminal with git access)

```bash
# Add all changes to git
git add -A

# Commit the changes
git commit -m "Added Department and Business Unit fields to ticket system

- Added requesterDepartment and requesterBusinessUnit fields to ticket schema
- Updated authenticated ticket form with department/business unit dropdowns  
- Updated anonymous ticket form with same fields
- Enhanced ticket details to display department and business unit
- Updated ticket list to show department information
- Business Unit options: BU1, BU2, BU3, BU4
- Department options: IT, Finance, HR, Operations, Sales, Marketing, Legal, Executive, Customer Service, R&D, Other"

# Push to remote repository
git push origin main
```

## Step 2: Production Server Deployment

Connect to your production server and execute these commands:

```bash
# Connect to production server
ssh ubuntu@54.160.177.174

# Navigate to application directory
cd /home/ubuntu/servicedesk

# Pull latest changes from git
git pull origin main

# Install any new dependencies
npm install

# Update database schema with new department/business unit fields
npx drizzle-kit push

# Restart the application
pm2 restart servicedesk

# Check application status
pm2 status servicedesk

# View recent logs to verify deployment
pm2 logs servicedesk --lines 10

# Test application endpoint
curl -s http://localhost:5000/api/auth/me || echo "Application is running"
```

## Step 3: Verification

After deployment, verify these features:

1. **Access Application**: http://54.160.177.174:5000
2. **Login**: john.doe / password123
3. **Test Authenticated Ticket Creation**:
   - Click "Create Ticket"
   - Verify Department dropdown has 11 options
   - Verify Business Unit dropdown has BU1-BU4 options
4. **Test Anonymous Ticket Creation**: 
   - Go to /public-ticket
   - Verify same Department and Business Unit fields are present
5. **View Existing Tickets**:
   - Check ticket details show department/business unit when available
   - Verify ticket list displays department information

## Files Modified

### Database Schema
- `shared/schema.ts` - Added requesterDepartment and requesterBusinessUnit fields

### Frontend Components
- `client/src/components/ticket-form.tsx` - Added dept/BU dropdowns to authenticated form
- `client/src/components/anonymous-ticket-form.tsx` - Added dept/BU dropdowns to anonymous form  
- `client/src/components/ticket-details-modal.tsx` - Display dept/BU in ticket details
- `client/src/components/tickets-list.tsx` - Show department in ticket list

## Department Options
- IT
- Finance  
- Human Resources
- Operations
- Sales
- Marketing
- Legal
- Executive
- Customer Service
- Research & Development
- Other

## Business Unit Options
- BU1
- BU2
- BU3
- BU4

## Troubleshooting

If deployment fails:

1. **Database Issues**: Ensure PostgreSQL is running and accessible
2. **Permission Issues**: Check file permissions on application directory
3. **Port Issues**: Verify port 5000 is open and not in use
4. **PM2 Issues**: Try `pm2 delete servicedesk` then `pm2 start ecosystem.config.js`

## Rollback Plan

If issues occur, rollback using:

```bash
# Navigate to backup directory (created automatically)
cd /home/ubuntu/servicedesk_backup_[timestamp]

# Copy backup files back
cp -r * /home/ubuntu/servicedesk/

# Restart application
cd /home/ubuntu/servicedesk
pm2 restart servicedesk
```

The deployment adds organizational tracking capabilities to your IT service desk while maintaining backward compatibility with existing tickets.