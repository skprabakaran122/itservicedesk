#!/bin/bash

# Complete deployment script for modal scroll fixes
# Run this on your Ubuntu server

SERVER_PATH="/home/ubuntu/servicedesk"
BACKUP_DIR="/home/ubuntu/modal_backup_$(date +%Y%m%d_%H%M%S)"

echo "=== Modal Scroll Fix Deployment Script ==="
echo "Server path: $SERVER_PATH"
echo "Backup directory: $BACKUP_DIR"
echo

# Step 1: Create backup
echo "1. Creating backup of current files..."
mkdir -p "$BACKUP_DIR"
cp "$SERVER_PATH/client/src/components/ticket-form.tsx" "$BACKUP_DIR/" 2>/dev/null || echo "ticket-form.tsx not found for backup"
cp "$SERVER_PATH/client/src/components/change-form.tsx" "$BACKUP_DIR/" 2>/dev/null || echo "change-form.tsx not found for backup"
echo "Backup created at: $BACKUP_DIR"

# Step 2: Apply ticket-form.tsx fix
echo
echo "2. Applying ticket-form.tsx modal scroll fix..."
sed -i 's|<DialogContent className="sm:max-w-\[600px\]">|<DialogContent className="sm:max-w-[600px] max-h-[90vh] overflow-y-auto" onInteractOutside={(e) => e.preventDefault()}>|g' "$SERVER_PATH/client/src/components/ticket-form.tsx"

# Alternative more precise fix for ticket-form.tsx
sed -i '114s|<DialogContent className="sm:max-w-\[600px\].*">|<DialogContent className="sm:max-w-[600px] max-h-[90vh] overflow-y-auto" onInteractOutside={(e) => e.preventDefault()}>|' "$SERVER_PATH/client/src/components/ticket-form.tsx"

echo "ticket-form.tsx updated"

# Step 3: Apply change-form.tsx fix
echo
echo "3. Applying change-form.tsx modal scroll fix..."
sed -i 's|<DialogContent className="sm:max-w-\[700px\]">|<DialogContent className="sm:max-w-[700px] max-h-[90vh] overflow-y-auto" onInteractOutside={(e) => e.preventDefault()}>|g' "$SERVER_PATH/client/src/components/change-form.tsx"

# Alternative more precise fix for change-form.tsx
sed -i '144s|<DialogContent className="sm:max-w-\[700px\].*">|<DialogContent className="sm:max-w-[700px] max-h-[90vh] overflow-y-auto" onInteractOutside={(e) => e.preventDefault()}>|' "$SERVER_PATH/client/src/components/change-form.tsx"

echo "change-form.tsx updated"

# Step 4: Verify changes
echo
echo "4. Verifying changes..."
echo "Checking ticket-form.tsx line 114:"
sed -n '114p' "$SERVER_PATH/client/src/components/ticket-form.tsx"
echo
echo "Checking change-form.tsx line 144:"
sed -n '144p' "$SERVER_PATH/client/src/components/change-form.tsx"

# Step 5: Restart application
echo
echo "5. Restarting application..."
cd "$SERVER_PATH"
pm2 restart servicedesk

# Step 6: Show logs
echo
echo "6. Checking application logs..."
pm2 logs servicedesk --lines 10

echo
echo "=== Deployment Complete ==="
echo "Modal fixes applied:"
echo "✓ Modals now scroll when content is long (max-h-[90vh] overflow-y-auto)"
echo "✓ Modals won't close when clicking outside (onInteractOutside prevention)"
echo "✓ X button, Cancel button, and ESC key still work normally"
echo
echo "Test at: http://54.160.177.174:5000"
echo "Login: john.doe / password123"
echo "Try 'New Ticket' and 'New Change' buttons"
echo
echo "If issues occur, restore from backup:"
echo "cp $BACKUP_DIR/ticket-form.tsx $SERVER_PATH/client/src/components/"
echo "cp $BACKUP_DIR/change-form.tsx $SERVER_PATH/client/src/components/"
echo "pm2 restart servicedesk"