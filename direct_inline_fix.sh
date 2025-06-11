#!/bin/bash

SERVER_PATH="/home/ubuntu/servicedesk"

echo "=== Direct Inline Style Fix ==="

# Create backup
cp "$SERVER_PATH/client/src/components/ticket-form.tsx" "$SERVER_PATH/client/src/components/ticket-form.tsx.backup3"
cp "$SERVER_PATH/client/src/components/change-form.tsx" "$SERVER_PATH/client/src/components/change-form.tsx.backup3"

# For ticket-form.tsx - Replace the entire DialogContent line with inline styles
sed -i 's|.*<DialogContent.*>|      <DialogContent className="sm:max-w-[600px]" style={{maxHeight: "90vh", overflowY: "auto"}} onInteractOutside={(e) => e.preventDefault()}>|' "$SERVER_PATH/client/src/components/ticket-form.tsx"

# For change-form.tsx - Replace the entire DialogContent line with inline styles  
sed -i 's|.*<DialogContent.*>|      <DialogContent className="sm:max-w-[700px]" style={{maxHeight: "90vh", overflowY: "auto"}} onInteractOutside={(e) => e.preventDefault()}>|' "$SERVER_PATH/client/src/components/change-form.tsx"

echo "Direct inline style replacement complete"

# Verify the changes
echo "=== Verification ==="
echo "ticket-form.tsx line with style:"
grep -n "style={{maxHeight" "$SERVER_PATH/client/src/components/ticket-form.tsx"
echo
echo "change-form.tsx line with style:"
grep -n "style={{maxHeight" "$SERVER_PATH/client/src/components/change-form.tsx"

# Restart application
cd "$SERVER_PATH"
pm2 restart servicedesk

echo "=== Complete ==="
echo "Inline styles should force scrolling behavior"
echo "The style={{maxHeight: '90vh', overflowY: 'auto'}} will override any CSS"