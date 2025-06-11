#!/bin/bash

SERVER_PATH="/home/ubuntu/servicedesk"

# Simple approach: Add a scrollable wrapper div around form content
echo "Applying scrollable wrapper fix..."

# ticket-form.tsx - add wrapper after DialogHeader and before Form
sed -i '/DialogHeader>/a\        <div style={{maxHeight: "70vh", overflowY: "auto", padding: "0.5rem"}}>/' "$SERVER_PATH/client/src/components/ticket-form.tsx"
sed -i '/DialogContent>/i\      </div>/' "$SERVER_PATH/client/src/components/ticket-form.tsx"

# change-form.tsx - add wrapper after DialogHeader and before Form  
sed -i '/DialogHeader>/a\        <div style={{maxHeight: "70vh", overflowY: "auto", padding: "0.5rem"}}>/' "$SERVER_PATH/client/src/components/change-form.tsx"
sed -i '/DialogContent>/i\      </div>/' "$SERVER_PATH/client/src/components/change-form.tsx"

# Add outside click prevention
sed -i 's|<DialogContent className="sm:max-w-\[600px\]">|<DialogContent className="sm:max-w-[600px]" onInteractOutside={(e) => e.preventDefault()}>|' "$SERVER_PATH/client/src/components/ticket-form.tsx"
sed -i 's|<DialogContent className="sm:max-w-\[700px\]">|<DialogContent className="sm:max-w-[700px]" onInteractOutside={(e) => e.preventDefault()}>|' "$SERVER_PATH/client/src/components/change-form.tsx"

# Restart
cd "$SERVER_PATH"
pm2 restart servicedesk

echo "Applied 70vh scrollable wrapper - test now"