#!/bin/bash

SERVER_PATH="/home/ubuntu/servicedesk"

echo "=== Robust Modal Fix Script ==="

# Backup files first
cp "$SERVER_PATH/client/src/components/ticket-form.tsx" "$SERVER_PATH/client/src/components/ticket-form.tsx.backup"
cp "$SERVER_PATH/client/src/components/change-form.tsx" "$SERVER_PATH/client/src/components/change-form.tsx.backup"

echo "Files backed up"

# Fix ticket-form.tsx - find and replace the exact DialogContent pattern
sed -i 's/<DialogContent className="sm:max-w-\[600px\]">/<DialogContent className="sm:max-w-[600px] max-h-[90vh] overflow-y-auto" onInteractOutside={(e) => e.preventDefault()}>/g' "$SERVER_PATH/client/src/components/ticket-form.tsx"

# Alternative pattern match for ticket-form.tsx
sed -i 's/<DialogContent className="sm:max-w-\[600px\]"[^>]*>/<DialogContent className="sm:max-w-[600px] max-h-[90vh] overflow-y-auto" onInteractOutside={(e) => e.preventDefault()}>/g' "$SERVER_PATH/client/src/components/ticket-form.tsx"

# Fix change-form.tsx - find and replace the exact DialogContent pattern
sed -i 's/<DialogContent className="sm:max-w-\[700px\]">/<DialogContent className="sm:max-w-[700px] max-h-[90vh] overflow-y-auto" onInteractOutside={(e) => e.preventDefault()}>/g' "$SERVER_PATH/client/src/components/change-form.tsx"

# Alternative pattern match for change-form.tsx
sed -i 's/<DialogContent className="sm:max-w-\[700px\]"[^>]*>/<DialogContent className="sm:max-w-[700px] max-h-[90vh] overflow-y-auto" onInteractOutside={(e) => e.preventDefault()}>/g' "$SERVER_PATH/client/src/components/change-form.tsx"

echo "Pattern replacements applied"

# Verify changes by searching for the new pattern
echo "=== Verification ==="
echo "Checking ticket-form.tsx for max-h-[90vh]:"
grep -n "max-h-\[90vh\]" "$SERVER_PATH/client/src/components/ticket-form.tsx" || echo "NOT FOUND"

echo "Checking change-form.tsx for max-h-[90vh]:"
grep -n "max-h-\[90vh\]" "$SERVER_PATH/client/src/components/change-form.tsx" || echo "NOT FOUND"

# Show current DialogContent lines
echo "=== Current DialogContent lines ==="
echo "ticket-form.tsx DialogContent:"
grep -n "DialogContent" "$SERVER_PATH/client/src/components/ticket-form.tsx"
echo
echo "change-form.tsx DialogContent:"
grep -n "DialogContent" "$SERVER_PATH/client/src/components/change-form.tsx"

# Restart application
echo "=== Restarting Application ==="
cd "$SERVER_PATH"
pm2 restart servicedesk
sleep 3
pm2 logs servicedesk --lines 5

echo "=== Complete ==="
echo "Test modals at: http://54.160.177.174:5000"
echo "If issues occur, restore backups:"
echo "cp $SERVER_PATH/client/src/components/ticket-form.tsx.backup $SERVER_PATH/client/src/components/ticket-form.tsx"
echo "cp $SERVER_PATH/client/src/components/change-form.tsx.backup $SERVER_PATH/client/src/components/change-form.tsx"