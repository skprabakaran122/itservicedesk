# Git Commit Instructions for Modal Fixes

## Changes Made
- Fixed ticket and change form modals to be scrollable
- Prevented modals from closing when clicking outside
- Fixed close button functionality (X button, Cancel button, ESC key)

## Files Modified
- `client/src/components/ticket-form.tsx`
- `client/src/components/change-form.tsx`

## Commands to Run on Server

### 1. Navigate to project directory
```bash
cd /home/ubuntu/servicedesk
```

### 2. Check current status
```bash
git status
```

### 3. Add the modified files
```bash
git add client/src/components/ticket-form.tsx
git add client/src/components/change-form.tsx
```

### 4. Commit the changes
```bash
git commit -m "Fix modal dialog usability issues

- Add scrollable content with max-height and overflow
- Prevent accidental closure when clicking outside modal
- Maintain close functionality via X button, Cancel, and ESC key
- Improve user experience for ticket and change form creation"
```

### 5. Push to repository
```bash
git push origin main
```

## Expected Output
After running these commands, you should see:
- Files staged and committed successfully
- Changes pushed to GitHub repository
- Modal improvements available in future deployments

## Verification
Test the changes by:
1. Opening "New Ticket" or "New Change"
2. Scrolling through the form (should work smoothly)
3. Clicking outside the modal (should NOT close)
4. Using X button or Cancel (should close properly)