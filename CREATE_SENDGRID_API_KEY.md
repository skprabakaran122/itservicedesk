# How to Create a New SendGrid API Key

## Step-by-Step Instructions

1. **Login to SendGrid Dashboard**
   - Go to https://app.sendgrid.com/
   - Login with your Calpion SendGrid credentials

2. **Navigate to API Keys**
   - Click on "Settings" in the left sidebar
   - Select "API Keys"

3. **Create New API Key**
   - Click "Create API Key" button
   - Choose "Restricted Access" for security
   - Name it something like "ServiceDesk-Production"

4. **Set Permissions**
   - **Mail Send**: Full Access (required for sending emails)
   - **IP Management**: No Access (we don't need this)
   - **Sender Authentication**: Read Access (optional)
   - Leave all other permissions as "No Access"

5. **Important: Do NOT Set IP Restrictions**
   - Leave the "IP Access Management" section empty
   - This allows the API key to work from any IP address

6. **Generate and Copy the Key**
   - Click "Create & View"
   - **IMPORTANT**: Copy the full API key immediately
   - It will start with "SG." and be about 69 characters long
   - You won't be able to see it again after closing this window

## After Creating the API Key

Once you have the new API key, provide it to me and I'll update the application configuration immediately.

## Current Configuration Ready

The application is already configured to use:
- **Sender Email**: `no-reply@calpion.com` ✅
- **API Key**: Waiting for your new unrestricted key

## Testing Process

After you provide the new API key:
1. I'll update the application configuration
2. Test email functionality with a sample ticket
3. Verify notifications work properly
4. Provide production deployment commands

The sender identity verification issue has already been resolved, so the new API key should work immediately.