#!/bin/bash

# Configure SMTP fallback for immediate email functionality
echo "Configuring SMTP fallback for email testing..."

# Login as admin
curl -s -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"password123"}' \
  -c smtp_cookies.txt > /dev/null

# Configure SMTP settings (using Gmail as example)
curl -s -X POST http://localhost:5000/api/email/settings \
  -H "Content-Type: application/json" \
  -b smtp_cookies.txt \
  -d '{
    "provider": "smtp",
    "smtpHost": "smtp.gmail.com",
    "smtpPort": 587,
    "smtpSecure": false,
    "smtpUser": "",
    "smtpPass": "",
    "fromEmail": "no-reply@calpion.com"
  }' > /dev/null

echo "SMTP configuration template created."
echo "To enable SMTP email:"
echo "1. Go to admin console > Email Settings"
echo "2. Switch to SMTP provider"
echo "3. Enter your SMTP credentials (Gmail, Outlook, etc.)"
echo "4. Test email functionality"

# Clean up
rm -f smtp_cookies.txt

echo ""
echo "Alternative: You can whitelist IP 34.169.194.177 in SendGrid to use the updated API key."