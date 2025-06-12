#!/bin/bash

# Fix Server Environment Variables
echo "Fixing server environment configuration..."

# Stop current PM2 processes
pm2 stop all
pm2 delete all

# Navigate to project directory
cd /home/ubuntu/servicedesk

# Create or update .env file with proper variables
cat > .env << 'EOF'
NODE_ENV=production
PORT=5000
DATABASE_URL=postgresql://servicedesk_user:password123@localhost:5432/servicedesk
SENDGRID_API_KEY=SG.placeholder_key_configure_in_admin
EOF

# Make sure .env is readable
chmod 644 .env

# Load environment variables
export $(cat .env | xargs)

# Start application with explicit environment loading
pm2 start ecosystem.config.cjs --env production

# Alternative method if above fails
if ! pm2 list | grep -q "servicedesk.*online"; then
    echo "Trying alternative startup method..."
    pm2 delete servicedesk 2>/dev/null || true
    
    # Start with explicit environment variables
    DATABASE_URL="postgresql://servicedesk_user:password123@localhost:5432/servicedesk" \
    SENDGRID_API_KEY="SG.placeholder_key" \
    NODE_ENV="production" \
    PORT="5000" \
    pm2 start npm --name servicedesk -- run dev
fi

# Save PM2 configuration
pm2 save

# Display status
echo "Application Status:"
pm2 status

echo "Environment Check:"
pm2 show servicedesk | grep -A 20 "env:"

echo "Recent Logs:"
pm2 logs servicedesk --lines 5

echo "If DATABASE_URL errors persist, check PostgreSQL service:"
echo "sudo systemctl status postgresql"
echo "sudo -u postgres psql -c \"SELECT 1;\""