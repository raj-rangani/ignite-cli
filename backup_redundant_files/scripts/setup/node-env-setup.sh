#!/bin/bash

# Script to set up Node.js environment after dev-cli.sh
# This script is a fallback for when the main workflow exits prematurely
# Usage: ./setup-node-env.sh [directory]

set -e

# Check if directory is provided
if [ -z "$1" ]; then
    echo "No directory specified, using current directory."
    DIR="."
else
    DIR="$1"
fi

echo "Setting up Node.js environment in $DIR"

# Check if port 3000 is already in use
PORT=3000
if netstat -tuln | grep -q ":3000 "; then
    echo "⚠️ Port 3000 is already in use. Setting port to 3001."
    PORT=3001
    # Check if 3001 is also in use
    if netstat -tuln | grep -q ":3001 "; then
        echo "⚠️ Port 3001 is also in use. Setting port to 3002."
        PORT=3002
    fi
fi

# Create .env file or overwrite if it exists
cat > "$DIR/.env" << EOF
# Server configuration
PORT=$PORT
NODE_ENV=development
API_PREFIX=/api/v1
LOG_LEVEL=info

# Database Configuration
DB_HOST=localhost
DB_PORT=5432
DB_NAME=postgres
DB_USER=postgres
DB_PASSWORD=postgres

# JWT Configuration
JWT_SECRET=your_jwt_secret_key
JWT_EXPIRES_IN=24h

# Application Settings
APP_NAME=nodejs-api
EOF

echo "✅ Environment configuration completed!"
echo "🚀 Server configured to run on port $PORT"

# Check if package.json exists and contains script section
if [ -f "$DIR/package.json" ]; then
    echo "🔍 Checking package.json for required dependencies..."
    
    # Check for essential packages and add if necessary
    if ! grep -q "express" "$DIR/package.json"; then
        echo "📦 Adding Express.js to dependencies..."
        cd "$DIR" && npm install --save express
    fi
    
    if ! grep -q "dotenv" "$DIR/package.json"; then
        echo "📦 Adding dotenv to dependencies..."
        cd "$DIR" && npm install --save dotenv
    fi
    
    if ! grep -q "nodemon" "$DIR/package.json"; then
        echo "📦 Adding nodemon to dev dependencies..."
        cd "$DIR" && npm install --save-dev nodemon
    fi
    
    echo "✅ Package dependencies checked and updated!"
else
    echo "⚠️ package.json not found in $DIR. Cannot check dependencies."
fi

# Create a README if it doesn't exist
if [ ! -f "$DIR/README.md" ]; then
    echo "📝 Creating README.md file..."
    cat > "$DIR/README.md" << EOF
# Node.js Application

## Setup

1. Install dependencies:
\`\`\`bash
npm install
\`\`\`

2. Environment configuration is in the \`.env\` file.

3. Start the server:
\`\`\`bash
npm start    # For production
npm run dev  # For development with auto-reload
\`\`\`

## Environment Variables

- \`PORT\`: The port the server runs on (default: $PORT)
- \`NODE_ENV\`: Environment mode (development, production)
- \`API_PREFIX\`: Prefix for API routes
- \`DB_HOST\`: Database host
- \`DB_PORT\`: Database port
- \`DB_NAME\`: Database name
- \`DB_USER\`: Database username
- \`DB_PASSWORD\`: Database password
- \`JWT_SECRET\`: Secret key for JWT tokens
- \`JWT_EXPIRES_IN\`: JWT token expiration time
EOF
    echo "✅ README.md created!"
fi

echo ""
echo "🎉 Setup completed! Your Node.js environment is ready."
echo "📊 Run your application with:"
echo "  npm start    # For production"
echo "  npm run dev  # For development with auto-reload" 