#!/bin/bash

echo "=== Manual Modal Fix Deployment ==="
echo "Copy these files to your Ubuntu server at /home/ubuntu/servicedesk/"
echo
echo "Files to update:"
echo "1. client/src/components/ticket-form.tsx"
echo "2. client/src/components/change-form.tsx"
echo
echo "Key changes made:"
echo "- ticket-form.tsx line 114: Added max-h-[90vh] overflow-y-auto + onInteractOutside prevention"
echo "- change-form.tsx line 144: Added max-h-[90vh] overflow-y-auto + onInteractOutside prevention"
echo
echo "After copying files, run on your server:"
echo "cd /home/ubuntu/servicedesk"
echo "pm2 restart servicedesk"
echo "pm2 logs servicedesk --lines 5"
echo
echo "Test at: http://54.160.177.174:5000"
echo "- Login: john.doe / password123"
echo "- Click 'New Ticket' - should scroll and not close when clicking outside"
echo "- Click 'New Change' - same behavior"
echo "- X button, Cancel, and ESC key should still work normally"