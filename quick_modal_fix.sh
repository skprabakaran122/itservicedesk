#!/bin/bash

# Quick 2-line modal fix script
# Run on Ubuntu server: ./quick_modal_fix.sh

SERVER_PATH="/home/ubuntu/servicedesk"

echo "Applying modal scroll fixes..."

# Fix ticket-form.tsx line 114
sed -i '114s|<DialogContent className="sm:max-w-\[600px\]">|<DialogContent className="sm:max-w-[600px] max-h-[90vh] overflow-y-auto" onInteractOutside={(e) => e.preventDefault()}>|' "$SERVER_PATH/client/src/components/ticket-form.tsx"

# Fix change-form.tsx line 144  
sed -i '144s|<DialogContent className="sm:max-w-\[700px\]">|<DialogContent className="sm:max-w-[700px] max-h-[90vh] overflow-y-auto" onInteractOutside={(e) => e.preventDefault()}>|' "$SERVER_PATH/client/src/components/change-form.tsx"

echo "Restarting application..."
cd "$SERVER_PATH"
pm2 restart servicedesk

echo "Done! Test at http://54.160.177.174:5000"