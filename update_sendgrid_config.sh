#!/bin/bash

# Update SendGrid Configuration Based on Postman Collection
echo "=== Updating SendGrid Configuration ==="

# From the Postman collection, the working configuration is:
# API Key: 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
# Sender Email: no-reply@calpion.com (with hyphen)

# Production server update commands:
cat << 'EOF'
Execute these commands on the production server:

# 1. Connect to production server
ssh ubuntu@54.160.177.174
cd /home/ubuntu/servicedesk

# 2. Update environment variables with working SendGrid config
cat > .env << 'EOL'
NODE_ENV=production
DATABASE_URL=postgresql://servicedesk_user:your_password@localhost:5432/servicedesk_db
SENDGRID_API_KEY=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
FROM_EMAIL=no-reply@calpion.com
SESSION_SECRET=your_32_character_session_secret
EOL

# 3. Set secure permissions
chmod 600 .env

# 4. Restart application
pm2 restart servicedesk

# 5. Test email functionality
pm2 logs servicedesk --lines 10

# 6. Verify SendGrid configuration
curl -X POST "http://localhost:5000/test-email" || echo "Email test endpoint not available"

echo "SendGrid configuration updated!"
echo "API Key: SG.2qoSI1pBRoSwH4BbTlJIHQ... (from Postman collection)"
echo "Sender Email: no-reply@calpion.com (verified in SendGrid)"
EOF

echo ""
echo "Key Information from Postman Collection:"
echo "======================================="
echo "Working API Key: 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"
echo "Verified Sender: no-reply@calpion.com"
echo ""
echo "Note: The sender email 'no-reply@calpion.com' (with hyphen) appears to be"
echo "verified in SendGrid based on your Postman tests, while 'noreply@calpion.com'"
echo "(without hyphen) is causing the verification error."