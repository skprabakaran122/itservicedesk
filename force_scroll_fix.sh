#!/bin/bash

SERVER_PATH="/home/ubuntu/servicedesk"

echo "=== Force Scroll Fix with Inline Styles ==="

# Backup current files
cp "$SERVER_PATH/client/src/components/ticket-form.tsx" "$SERVER_PATH/client/src/components/ticket-form.tsx.backup2"
cp "$SERVER_PATH/client/src/components/change-form.tsx" "$SERVER_PATH/client/src/components/change-form.tsx.backup2"

# Apply inline style fix to ticket-form.tsx - this will override any CSS conflicts
sed -i 's|<DialogContent className="sm:max-w-\[600px\][^"]*"|<DialogContent className="sm:max-w-[600px]" style={{maxHeight: "90vh", overflowY: "auto", padding: "1.5rem"}}|g' "$SERVER_PATH/client/src/components/ticket-form.tsx"

# Apply inline style fix to change-form.tsx
sed -i 's|<DialogContent className="sm:max-w-\[700px\][^"]*"|<DialogContent className="sm:max-w-[700px]" style={{maxHeight: "90vh", overflowY: "auto", padding: "1.5rem"}}|g' "$SERVER_PATH/client/src/components/change-form.tsx"

# Also keep the onInteractOutside prevention
sed -i 's|onInteractOutside={(e) => e.preventDefault()}||g' "$SERVER_PATH/client/src/components/ticket-form.tsx"
sed -i 's|onInteractOutside={(e) => e.preventDefault()}||g' "$SERVER_PATH/client/src/components/change-form.tsx"

sed -i 's|style={{maxHeight: "90vh", overflowY: "auto", padding: "1.5rem"}}>|style={{maxHeight: "90vh", overflowY: "auto", padding: "1.5rem"}} onInteractOutside={(e) => e.preventDefault()}>|g' "$SERVER_PATH/client/src/components/ticket-form.tsx"
sed -i 's|style={{maxHeight: "90vh", overflowY: "auto", padding: "1.5rem"}}>|style={{maxHeight: "90vh", overflowY: "auto", padding: "1.5rem"}} onInteractOutside={(e) => e.preventDefault()}>|g' "$SERVER_PATH/client/src/components/change-form.tsx"

echo "Inline style fixes applied"

# Verify the changes
echo "=== Verification ==="
echo "ticket-form.tsx DialogContent line:"
grep -n "DialogContent.*style=" "$SERVER_PATH/client/src/components/ticket-form.tsx"
echo
echo "change-form.tsx DialogContent line:"
grep -n "DialogContent.*style=" "$SERVER_PATH/client/src/components/change-form.tsx"

# Restart PM2
cd "$SERVER_PATH"
pm2 restart servicedesk

echo "=== Complete ==="
echo "Inline styles should force scroll behavior regardless of CSS conflicts"
echo "Test at http://54.160.177.174:5000"