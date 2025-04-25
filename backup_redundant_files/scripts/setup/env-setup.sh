#!/bin/bash

# Standalone environment setup script
# This script only sets up the .env file without installing dependencies
# Usage: ./env-setup-first.sh [project_directory]

set -e

# Check if directory is provided
if [ -z "$1" ]; then
    echo "No directory specified, using current directory."
    DIR="."
else
    DIR="$1"
fi

echo "🚀 Setting up environment for Node.js project in $DIR"
echo ""

# Create .env file or overwrite if it exists
cat > "$DIR/.env" << EOF
# Server configuration
PORT=3000
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
echo ""
echo "Your .env file contains:"
echo "------------------------"
cat "$DIR/.env"
echo "------------------------"
echo ""
echo "Now you can run 'npm install' to install dependencies."
echo "After installation, start your server with 'npm start' or 'npm run dev'"
echo ""
echo "✨ If you want to customize database settings, edit the .env file:"
echo "   vi $DIR/.env" 