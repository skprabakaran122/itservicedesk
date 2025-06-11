#!/bin/bash

SERVER_PATH="/home/ubuntu/servicedesk"

echo "=== Form Wrapper Scroll Fix ==="

# Backup files
cp "$SERVER_PATH/client/src/components/ticket-form.tsx" "$SERVER_PATH/client/src/components/ticket-form.tsx.backup4"
cp "$SERVER_PATH/client/src/components/change-form.tsx" "$SERVER_PATH/client/src/components/change-form.tsx.backup4"

# For ticket-form.tsx - wrap the form in a scrollable div
sed -i 's|<Form {...form}>|<div style={{maxHeight: "80vh", overflowY: "auto", padding: "1rem"}}>\n        <Form {...form}>|' "$SERVER_PATH/client/src/components/ticket-form.tsx"
sed -i 's|</Form>|</Form>\n      </div>|' "$SERVER_PATH/client/src/components/ticket-form.tsx"

# For change-form.tsx - wrap the form in a scrollable div
sed -i 's|<Form {...form}>|<div style={{maxHeight: "80vh", overflowY: "auto", padding: "1rem"}}>\n        <Form {...form}>|' "$SERVER_PATH/client/src/components/change-form.tsx"
sed -i 's|</Form>|</Form>\n      </div>|' "$SERVER_PATH/client/src/components/change-form.tsx"

# Also fix the outside click prevention on DialogContent
sed -i 's|<DialogContent className="sm:max-w-\[600px\][^>]*>|<DialogContent className="sm:max-w-[600px]" onInteractOutside={(e) => e.preventDefault()}>|' "$SERVER_PATH/client/src/components/ticket-form.tsx"
sed -i 's|<DialogContent className="sm:max-w-\[700px\][^>]*>|<DialogContent className="sm:max-w-[700px]" onInteractOutside={(e) => e.preventDefault()}>|' "$SERVER_PATH/client/src/components/change-form.tsx"

echo "Form wrapper scroll fix applied"

# Verify changes
echo "=== Verification ==="
echo "Checking for scrollable wrapper in ticket-form.tsx:"
grep -n "maxHeight.*80vh" "$SERVER_PATH/client/src/components/ticket-form.tsx"
echo
echo "Checking for scrollable wrapper in change-form.tsx:"
grep -n "maxHeight.*80vh" "$SERVER_PATH/client/src/components/change-form.tsx"

# Restart application
cd "$SERVER_PATH"
pm2 restart servicedesk

echo "=== Complete ==="
echo "Forms now wrapped in scrollable containers with 80vh max height"