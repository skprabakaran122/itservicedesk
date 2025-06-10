# Setting up GitHub Repository for IT Service Desk

## Step 1: Create GitHub Repository

1. Go to [GitHub.com](https://github.com) and sign in
2. Click the "+" icon in top right corner
3. Select "New repository"
4. Repository settings:
   - Repository name: `it-servicedesk` or `servicedesk`
   - Description: `IT Service Desk application with ticket and change management`
   - Set to Public or Private (your choice)
   - Don't initialize with README (since you already have code)
5. Click "Create repository"

## Step 2: Push Your Code to GitHub

After creating the repository, GitHub will show you commands. Use these in your Replit terminal:

```bash
# Initialize git if not already done
git init

# Add all files
git add .

# Commit your code
git commit -m "Initial commit - IT Service Desk application"

# Add the GitHub repository as origin (replace with your actual repository URL)
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPOSITORY_NAME.git

# Push to GitHub
git branch -M main
git push -u origin main
```

## Step 3: Update Deployment Script

Once your repository is created, update the deployment script with your actual repository URL:

```bash
# In deploy.sh, replace the clone command with:
git clone https://github.com/YOUR_USERNAME/YOUR_REPOSITORY_NAME.git servicedesk
```

## Alternative: Use Replit Git Integration

1. In Replit, go to the "Version Control" tab (git icon in left sidebar)
2. Click "Create a Git repo"
3. Connect to GitHub account
4. Push to GitHub directly from Replit interface

## Alternative: Manual File Transfer Method

If you prefer not to use Git:

1. **Download project files:**
   - In Replit, use Files panel
   - Download all files manually or create a zip

2. **Transfer to Ubuntu server:**
   ```bash
   # On your Ubuntu server
   mkdir servicedesk
   cd servicedesk
   # Upload files here via SCP, FTP, or manual copy
   ```

3. **Skip git clone in deployment:**
   ```bash
   # Instead of git clone, just cd into your uploaded directory
   cd servicedesk
   # Then continue with npm install and deployment steps
   ```

## Recommended Repository Structure

Your repository should include:
```
servicedesk/
├── client/
├── server/
├── shared/
├── package.json
├── package-lock.json
├── vite.config.ts
├── tsconfig.json
├── tailwind.config.ts
├── drizzle.config.ts
├── .gitignore
├── deploy.sh
├── DEPLOYMENT_GUIDE.md
├── servicedesk.service
└── README.md
```

## Update .gitignore

Create/update `.gitignore` to exclude sensitive files:

```
node_modules/
dist/
.env
.env.local
.env.production
logs/
*.log
.DS_Store
```

This ensures sensitive information like database passwords aren't pushed to GitHub.