#!/bin/bash

# Direct line replacement script
SERVER_PATH="/home/ubuntu/servicedesk"

echo "=== Current line content check ==="
echo "Line 114 in ticket-form.tsx:"
sed -n '114p' "$SERVER_PATH/client/src/components/ticket-form.tsx"
echo
echo "Line 144 in change-form.tsx:"
sed -n '144p' "$SERVER_PATH/client/src/components/change-form.tsx"
echo

echo "=== Applying direct line replacements ==="

# Replace entire line 114 in ticket-form.tsx
sed -i '114c\      <DialogContent className="sm:max-w-[600px] max-h-[90vh] overflow-y-auto" onInteractOutside={(e) => e.preventDefault()}>' "$SERVER_PATH/client/src/components/ticket-form.tsx"

# Replace entire line 144 in change-form.tsx  
sed -i '144c\      <DialogContent className="sm:max-w-[700px] max-h-[90vh] overflow-y-auto" onInteractOutside={(e) => e.preventDefault()}>' "$SERVER_PATH/client/src/components/change-form.tsx"

echo "=== Verification ==="
echo "New line 114 in ticket-form.tsx:"
sed -n '114p' "$SERVER_PATH/client/src/components/ticket-form.tsx"
echo
echo "New line 144 in change-form.tsx:"
sed -n '144p' "$SERVER_PATH/client/src/components/change-form.tsx"
echo

echo "Restarting PM2..."
cd "$SERVER_PATH"
pm2 restart servicedesk
pm2 logs servicedesk --lines 5

echo "Test modals at http://54.160.177.174:5000"