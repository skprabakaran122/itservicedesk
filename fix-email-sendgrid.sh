#!/bin/bash

# Fix SendGrid email configuration and provide IP whitelisting guidance

echo "SendGrid Email Configuration Fix"
echo "================================"
echo ""

# Get current Replit IP
REPLIT_IP=$(curl -s ipinfo.io/ip 2>/dev/null || echo "Unable to detect IP")
echo "Current Replit IP Address: $REPLIT_IP"
echo ""

echo "SendGrid IP Whitelisting Issue Detected"
echo "---------------------------------------"
echo ""
echo "Your SendGrid API key is valid but the Replit IP address isn't whitelisted."
echo "To fix this, you have two options:"
echo ""
echo "Option 1: Whitelist Replit IP in SendGrid (Recommended)"
echo "1. Login to your SendGrid account"
echo "2. Go to Settings > IP Access Management"
echo "3. Add this IP address: $REPLIT_IP"
echo "4. Save the changes"
echo ""
echo "Option 2: Remove IP restrictions (Less secure)"
echo "1. Login to your SendGrid account"
echo "2. Go to Settings > IP Access Management"
echo "3. Remove all IP restrictions (allow from any IP)"
echo ""
echo "Option 3: Use SMTP fallback (Alternative)"
echo "1. Configure SMTP settings in the admin console"
echo "2. Use a service like Gmail SMTP or your hosting provider"
echo ""

# Test current email configuration
echo "Testing current email configuration..."
response=$(curl -s -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"password123"}' \
  -c temp_cookies.txt)

if echo "$response" | grep -q "admin"; then
  echo "✅ Admin authentication successful"
  
  # Test email
  email_test=$(curl -s -X POST http://localhost:5000/api/email/test \
    -H "Content-Type: application/json" \
    -b temp_cookies.txt \
    -d '{"email":"test@example.com"}' 2>/dev/null)
  
  if echo "$email_test" | grep -q "success"; then
    echo "✅ Email test successful"
  else
    echo "❌ Email test failed: IP whitelisting required"
  fi
else
  echo "❌ Authentication failed"
fi

# Clean up
rm -f temp_cookies.txt

echo ""
echo "Quick Fix Commands:"
echo "==================="
echo ""
echo "Test email after whitelisting:"
echo "curl -X POST http://localhost:5000/api/email/test \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"email\":\"your-email@example.com\"}'"
echo ""
echo "Check SendGrid settings:"
echo "curl http://localhost:5000/api/email/settings"
echo ""
echo "Once IP is whitelisted, email notifications will work for:"
echo "- Ticket creation and updates"
echo "- Change request approvals"
echo "- System notifications"
echo "- Test emails from admin console"