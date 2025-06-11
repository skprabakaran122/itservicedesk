#!/bin/bash

SERVER_PATH="/home/ubuntu/servicedesk"

echo "Manual line replacement script"

# Create backup
cp "$SERVER_PATH/client/src/components/ticket-form.tsx" "$SERVER_PATH/client/src/components/ticket-form.tsx.original"
cp "$SERVER_PATH/client/src/components/change-form.tsx" "$SERVER_PATH/client/src/components/change-form.tsx.original"

# Replace line 114 in ticket-form.tsx exactly
sed -i '114c\      <DialogContent className="sm:max-w-[600px]" style={{maxHeight: "85vh", overflowY: "auto"}} onInteractOutside={(e) => e.preventDefault()}>' "$SERVER_PATH/client/src/components/ticket-form.tsx"

# Replace line 144 in change-form.tsx exactly  
sed -i '144c\      <DialogContent className="sm:max-w-[700px]" style={{maxHeight: "85vh", overflowY: "auto"}} onInteractOutside={(e) => e.preventDefault()}>' "$SERVER_PATH/client/src/components/change-form.tsx"

echo "Lines replaced with inline styles"

# Show what we changed
echo "ticket-form.tsx line 114:"
sed -n '114p' "$SERVER_PATH/client/src/components/ticket-form.tsx"
echo
echo "change-form.tsx line 144:"
sed -n '144p' "$SERVER_PATH/client/src/components/change-form.tsx"

# Restart
cd "$SERVER_PATH"
pm2 restart servicedesk

echo "Done - inline styles force scroll at 85vh height"