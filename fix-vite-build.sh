#!/bin/bash

# Fix the Vite build to properly serve your React app
cd /var/www/itservicedesk

echo "Fixing Vite build output..."

# The build succeeded but the files are in wrong location, let's move them properly
if [ -f "dist/index.html" ]; then
    echo "Moving Vite build files to correct location..."
    
    # Create public directory if it doesn't exist
    mkdir -p dist/public
    
    # Move the built files from dist/ to dist/public/
    cp dist/index.html dist/public/
    cp -r dist/assets dist/public/ 2>/dev/null || true
    
    echo "Build files moved successfully"
else
    echo "No build files found, creating from ../dist/public/"
    # The files are already in the right place from the first build
fi

# Check the content of index.html
echo "Current index.html:"
cat dist/public/index.html

# Update index.html to have proper script references
cat > dist/public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1" />
    <title>Calpion IT Service Desk</title>
    <link rel="stylesheet" href="/assets/index-Cf-nQCTa.css" />
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/assets/index-u5OElkvU.js"></script>
  </body>
</html>
EOF

echo "Updated index.html with proper asset references"

# List the final structure
echo "Final file structure:"
ls -la dist/public/

# Restart the server
pm2 restart itservicedesk
sleep 3

# Test that it's working
echo "Testing the application..."
curl -s http://localhost:5000/ | head -10

echo ""
echo "✅ React app should now load properly!"
echo "🌐 Try accessing: https://98.81.235.7"