#!/bin/bash

SERVER_PATH="/home/ubuntu/servicedesk"

echo "=== Modal CSS Debug Script ==="

# Check if the changes are actually in the files
echo "1. Verifying DialogContent lines:"
echo "ticket-form.tsx line 114:"
sed -n '114p' "$SERVER_PATH/client/src/components/ticket-form.tsx"
echo
echo "change-form.tsx line 144:"
sed -n '144p' "$SERVER_PATH/client/src/components/change-form.tsx"
echo

# Check for any CSS conflicts in tailwind config
echo "2. Checking for CSS max-height conflicts:"
grep -r "max-h" "$SERVER_PATH/client/src/" --include="*.css" --include="*.tsx" | head -10

# Check if there are any global CSS overrides
echo "3. Checking global CSS files:"
find "$SERVER_PATH" -name "*.css" -type f | head -5

# Check if Tailwind is compiling properly
echo "4. Testing Tailwind classes - checking for other max-h usage:"
grep -r "max-h-\[" "$SERVER_PATH/client/src/" --include="*.tsx" | head -5

# Check the actual compiled CSS (if accessible)
echo "5. Checking for Dialog component overrides:"
grep -r "DialogContent" "$SERVER_PATH/client/src/" --include="*.tsx" | grep -v "import" | head -3

echo "=== Applying Alternative Fix ==="

# Try a different approach - add CSS class
sed -i 's/max-h-\[90vh\] overflow-y-auto/max-h-\[90vh\] overflow-y-auto scrollable-modal/g' "$SERVER_PATH/client/src/components/ticket-form.tsx"
sed -i 's/max-h-\[90vh\] overflow-y-auto/max-h-\[90vh\] overflow-y-auto scrollable-modal/g' "$SERVER_PATH/client/src/components/change-form.tsx"

# Add inline style as backup
sed -i 's/onInteractOutside={(e) => e.preventDefault()}/onInteractOutside={(e) => e.preventDefault()} style={{maxHeight: "90vh", overflowY: "auto"}}/g' "$SERVER_PATH/client/src/components/ticket-form.tsx"
sed -i 's/onInteractOutside={(e) => e.preventDefault()}/onInteractOutside={(e) => e.preventDefault()} style={{maxHeight: "90vh", overflowY: "auto"}}/g' "$SERVER_PATH/client/src/components/change-form.tsx"

echo "Alternative fixes applied"

# Restart application
cd "$SERVER_PATH"
pm2 restart servicedesk

echo "=== Debug Complete ==="
echo "Check browser developer tools:"
echo "1. Right-click on modal -> Inspect Element"
echo "2. Look for DialogContent element"
echo "3. Check if max-height: 90vh and overflow-y: auto are applied"
echo "4. Check if any parent elements have overflow: hidden"