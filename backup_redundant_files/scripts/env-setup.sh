#!/bin/bash

# =============================================
# Unified Environment Setup Script
# =============================================
# Usage: ./env-setup.sh [project_directory] [framework_type]

# Set error handling
set -e

# Get the directory of the script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

# Check if directory is provided
if [ -z "$1" ]; then
    echo "No directory specified, using current directory."
    DIR="."
else
    DIR="$1"
fi

# Check if framework type is provided
if [ -z "$2" ]; then
    FRAMEWORK="nodejs"  # Default to Node.js
else
    FRAMEWORK="$2"
fi

echo "🚀 Setting up environment for ${FRAMEWORK} project in ${DIR}"
echo ""

# Check for port availability (for server-based projects)
PORT=3000
if [[ "${FRAMEWORK}" == "nodejs" || "${FRAMEWORK}" == "mern" || "${FRAMEWORK}" == "laravel" ]]; then
    if netstat -tuln | grep -q ":3000 "; then
        echo "⚠️ Port 3000 is already in use. Setting port to 3001."
        PORT=3001
        # Check if 3001 is also in use
        if netstat -tuln | grep -q ":3001 "; then
            echo "⚠️ Port 3001 is also in use. Setting port to 3002."
            PORT=3002
        fi
    fi
fi

# Create environment file based on framework type
case "${FRAMEWORK}" in
    nodejs|mern|mean)
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
        
        # Check and update package.json if it exists
        if [ -f "$DIR/package.json" ]; then
            echo "🔍 Checking package.json for required dependencies..."
            
            cd "$DIR"
            
            # Check for essential packages and add if necessary
            if ! grep -q "express" "package.json"; then
                echo "📦 Adding Express.js to dependencies..."
                npm install --save express
            fi
            
            if ! grep -q "dotenv" "package.json"; then
                echo "📦 Adding dotenv to dependencies..."
                npm install --save dotenv
            fi
            
            if ! grep -q "nodemon" "package.json"; then
                echo "📦 Adding nodemon to dev dependencies..."
                npm install --save-dev nodemon
            fi
            
            echo "✅ Package dependencies checked and updated!"
        fi
        ;;
        
    react|vue)
        cat > "$DIR/.env" << EOF
# React/Vue environment configuration
REACT_APP_API_URL=http://localhost:$PORT/api
VUE_APP_API_URL=http://localhost:$PORT/api
NODE_ENV=development
PORT=$PORT
EOF
        ;;
        
    angular)
        # Angular uses environment.ts instead of .env
        if [ ! -f "$DIR/src/environments/environment.ts" ]; then
            mkdir -p "$DIR/src/environments"
            cat > "$DIR/src/environments/environment.ts" << EOF
export const environment = {
  production: false,
  apiUrl: 'http://localhost:$PORT/api'
};
EOF
        fi
        
        if [ ! -f "$DIR/src/environments/environment.prod.ts" ]; then
            mkdir -p "$DIR/src/environments"
            cat > "$DIR/src/environments/environment.prod.ts" << EOF
export const environment = {
  production: true,
  apiUrl: '/api'
};
EOF
        fi
        
        # Also create .env for any tools that might use it
        cat > "$DIR/.env" << EOF
# Angular environment configuration
API_URL=http://localhost:$PORT/api
NODE_ENV=development
PORT=$PORT
EOF
        ;;
        
    flutter)
        cat > "$DIR/.env" << EOF
# Flutter configuration
API_URL=http://localhost:$PORT/api
EOF
        
        # For Flutter, also create a config file that can be used in the app
        mkdir -p "$DIR/lib/config"
        cat > "$DIR/lib/config/environment.dart" << EOF
class Environment {
  static const String apiUrl = 'http://localhost:$PORT/api';
  static const bool isDevelopment = true;
}
EOF
        ;;
        
    laravel)
        if [ -f "$DIR/.env.example" ]; then
            cp "$DIR/.env.example" "$DIR/.env"
            echo "✅ Created .env from .env.example"
        else
            cat > "$DIR/.env" << EOF
APP_NAME=Laravel
APP_ENV=local
APP_KEY=
APP_DEBUG=true
APP_URL=http://localhost:$PORT

LOG_CHANNEL=stack
LOG_LEVEL=debug

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=laravel
DB_USERNAME=root
DB_PASSWORD=

BROADCAST_DRIVER=log
CACHE_DRIVER=file
QUEUE_CONNECTION=sync
SESSION_DRIVER=file
SESSION_LIFETIME=120
EOF
        fi
        
        # Generate app key if it doesn't exist
        if command -v php &> /dev/null && [ -f "$DIR/artisan" ]; then
            cd "$DIR"
            php artisan key:generate --ansi
        fi
        ;;
        
    *)
        echo "⚠️ Unknown framework: $FRAMEWORK. Using generic environment setup."
        cat > "$DIR/.env" << EOF
# Generic environment configuration
PORT=$PORT
NODE_ENV=development
API_URL=http://localhost:$PORT/api
EOF
        ;;
esac

echo "✅ Environment configuration completed!"
echo ""
echo "Your .env file contains:"
echo "------------------------"
cat "$DIR/.env"
echo "------------------------"
echo ""

# Create a README if it doesn't exist
if [ ! -f "$DIR/README.md" ]; then
    echo "📝 Creating README.md file..."
    
    cat > "$DIR/README.md" << EOF
# ${FRAMEWORK^} Project

## Setup

1. Install dependencies:
\`\`\`bash
EOF
    
    case "${FRAMEWORK}" in
        nodejs|mern|mean|react|vue|angular)
            echo "npm install" >> "$DIR/README.md"
            ;;
        flutter)
            echo "flutter pub get" >> "$DIR/README.md"
            ;;
        laravel)
            echo "composer install" >> "$DIR/README.md"
            ;;
    esac
    
    cat >> "$DIR/README.md" << EOF
\`\`\`

2. Environment configuration is in the \`.env\` file.

3. Start the application:
\`\`\`bash
EOF
    
    case "${FRAMEWORK}" in
        nodejs|mern|mean)
            echo "npm start    # For production" >> "$DIR/README.md"
            echo "npm run dev  # For development with auto-reload" >> "$DIR/README.md"
            ;;
        react)
            echo "npm start" >> "$DIR/README.md"
            ;;
        vue)
            echo "npm run serve" >> "$DIR/README.md"
            ;;
        angular)
            echo "ng serve" >> "$DIR/README.md"
            ;;
        flutter)
            echo "flutter run" >> "$DIR/README.md"
            ;;
        laravel)
            echo "php artisan serve" >> "$DIR/README.md"
            ;;
    esac
    
    cat >> "$DIR/README.md" << EOF
\`\`\`
EOF
    
    echo "✅ README.md created!"
fi

echo ""
echo "🎉 Environment setup completed! Your ${FRAMEWORK^} project is configured." 