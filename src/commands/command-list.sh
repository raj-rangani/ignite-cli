#!/bin/bash
# =============================================
# Command List
# Shows useful commands for selected framework
# =============================================

# Source utility scripts
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
source "${PARENT_DIR}/utils/logger.sh"
source "${PARENT_DIR}/utils/config.sh"
source "${PARENT_DIR}/utils/validators.sh"
source "${PARENT_DIR}/utils/framework.sh"

# Display help message for this command
function show_help() {
    log_info "Developer CLI - Command List"
    log_info ""
    log_info "Usage: dev-cli commands [OPTIONS]"
    log_info ""
    log_info "Options:"
    log_info "  --framework=NAME     Specify the framework to use"
    log_info "  -h, --help           Show this help message"
    log_info ""
    log_info "Examples:"
    log_info "  dev-cli commands"
    log_info "  dev-cli commands --framework=nodejs"
}

# Function to show useful commands for a framework
function show_commands() {
    local framework="$1"
    
    # If no framework is provided, try to get it from config
    if [[ -z "${framework}" ]]; then
        framework=$(get_config "SELECTED_FRAMEWORK")
        
        # If still no framework, prompt user to select one
        if [[ -z "${framework}" ]]; then
            log_warning "Framework not set. Please select a framework first."
            
            # Source the framework command to select a framework
            source "${SCRIPT_DIR}/framework.sh"
            
            # Get the selected framework from config
            framework=$(get_config "SELECTED_FRAMEWORK")
            
            # Check if framework selection was successful
            if [[ -z "${framework}" ]]; then
                log_error "Failed to select framework."
                return 1
            fi
        fi
    fi
    
    log_section "Useful Commands for ${framework^}"
    echo ""
    
    case "${framework}" in
        nodejs)
            echo ">> Development Commands"
            echo "npm start         - Start the server"
            echo "npm run dev       - Start the server with hot-reload (using nodemon)"
            echo "npm test          - Run tests"
            echo ""
            echo ">> Common NPM Commands"
            echo "npm install <pkg>      - Install package and add to package.json"
            echo "npm install --save-dev <pkg> - Install package as dev dependency"
            echo "npm uninstall <pkg>    - Remove package"
            echo "npm update             - Update packages"
            echo ""
            echo ">> Express.js Commands"
            echo "# Create a new route in src/routes/"
            echo "# Import route in src/index.js and use with app.use()"
            echo ""
            echo ">> Database Commands (if using MongoDB)"
            echo "mongod          - Start MongoDB server"
            echo "mongo           - Open MongoDB shell"
            echo "# Using Mongoose in your code:"
            echo "const mongoose = require('mongoose');"
            echo "mongoose.connect('mongodb://localhost/your-db-name');"
            ;;
            
        react)
            echo ">> Development Commands"
            echo "npm start       - Start development server"
            echo "npm test        - Run tests"
            echo "npm run build   - Build for production"
            echo "npm run eject   - Eject from Create React App (caution!)"
            echo ""
            echo ">> Common NPM Commands"
            echo "npm install <pkg>      - Install package and add to package.json"
            echo "npm install --save-dev <pkg> - Install package as dev dependency"
            echo "npm uninstall <pkg>    - Remove package"
            echo ""
            echo ">> Creating Components"
            echo "# Create functional component:"
            echo "function MyComponent() {"
            echo "  return <div>Hello</div>;"
            echo "}"
            echo ""
            echo "# Create class component:"
            echo "class MyComponent extends React.Component {"
            echo "  render() {"
            echo "    return <div>Hello</div>;"
            echo "  }"
            echo "}"
            ;;
            
        angular)
            echo ">> Angular CLI Commands"
            echo "ng serve          - Start development server"
            echo "ng build          - Build application"
            echo "ng test           - Run tests"
            echo "ng e2e            - Run end-to-end tests"
            echo ""
            echo ">> Generating Components"
            echo "ng generate component my-component"
            echo "ng generate service my-service"
            echo "ng generate module my-module"
            echo "ng generate pipe my-pipe"
            echo "ng generate directive my-directive"
            echo "ng generate guard my-guard"
            echo "ng generate interface my-interface"
            echo "ng generate enum my-enum"
            echo ""
            echo ">> Common NPM Commands"
            echo "npm install <pkg>      - Install package and add to package.json"
            echo "npm install --save-dev <pkg> - Install package as dev dependency"
            echo "npm uninstall <pkg>    - Remove package"
            ;;
            
        vue)
            echo ">> Vue CLI Commands"
            echo "npm run serve     - Start development server"
            echo "npm run build     - Build for production"
            echo "npm run test:unit - Run unit tests"
            echo "npm run test:e2e  - Run end-to-end tests"
            echo "npm run lint      - Lint and fix files"
            echo ""
            echo ">> Vue UI (if installed)"
            echo "vue ui            - Start Vue UI"
            echo ""
            echo ">> Common NPM Commands"
            echo "npm install <pkg>      - Install package and add to package.json"
            echo "npm install --save-dev <pkg> - Install package as dev dependency"
            echo "npm uninstall <pkg>    - Remove package"
            ;;
            
        flutter)
            echo ">> Flutter Commands"
            echo "flutter run       - Run Flutter application"
            echo "flutter build     - Build Flutter application"
            echo "flutter test      - Run Flutter tests"
            echo "flutter analyze   - Analyze code"
            echo "flutter clean     - Clean project"
            echo ""
            echo ">> Package Management"
            echo "flutter pub get   - Get packages"
            echo "flutter pub upgrade - Upgrade packages"
            echo "flutter pub outdated - Check for outdated packages"
            echo ""
            echo ">> Creating Components"
            echo "# Use StatelessWidget for static UI"
            echo "# Use StatefulWidget for dynamic UI"
            echo ""
            echo ">> Emulator/Device Commands"
            echo "flutter devices   - List connected devices"
            echo "flutter emulators - List available emulators"
            echo "flutter emulators --launch <emulator_id> - Launch emulator"
            ;;
            
        react-native)
            echo ">> React Native Commands"
            echo "npx react-native start       - Start Metro bundler"
            echo "npx react-native run-android - Run on Android"
            echo "npx react-native run-ios     - Run on iOS"
            echo "npx react-native log-android - Show Android logs"
            echo "npx react-native log-ios     - Show iOS logs"
            echo ""
            echo ">> Common NPM Commands"
            echo "npm install <pkg>      - Install package and add to package.json"
            echo "npm install --save-dev <pkg> - Install package as dev dependency"
            echo "npm uninstall <pkg>    - Remove package"
            echo ""
            echo ">> Debugging"
            echo "# Shake device or press Cmd+D (iOS) / Cmd+M (Android) in simulator"
            echo "# to open developer menu"
            ;;
            
        laravel)
            echo ">> Laravel Commands"
            echo "php artisan serve            - Start development server"
            echo "php artisan migrate          - Run migrations"
            echo "php artisan make:controller  - Create controller"
            echo "php artisan make:model       - Create model"
            echo "php artisan make:migration   - Create migration"
            echo "php artisan make:seeder      - Create seeder"
            echo "php artisan make:middleware  - Create middleware"
            echo "php artisan make:request     - Create form request"
            echo "php artisan make:command     - Create command"
            echo ""
            echo ">> Database Commands"
            echo "php artisan db:seed          - Run seeders"
            echo "php artisan migrate:reset    - Reset migrations"
            echo "php artisan migrate:refresh  - Reset and re-run migrations"
            echo "php artisan migrate:status   - Check migration status"
            echo ""
            echo ">> Cache Commands"
            echo "php artisan config:cache     - Cache config"
            echo "php artisan route:cache      - Cache routes"
            echo "php artisan view:cache       - Cache views"
            echo "php artisan cache:clear      - Clear cache"
            ;;
            
        django)
            echo ">> Django Commands"
            echo "python manage.py runserver         - Start development server"
            echo "python manage.py migrate           - Apply migrations"
            echo "python manage.py makemigrations    - Create migrations"
            echo "python manage.py createsuperuser   - Create admin user"
            echo "python manage.py shell             - Open Django shell"
            echo "python manage.py test              - Run tests"
            echo "python manage.py collectstatic     - Collect static files"
            echo ""
            echo ">> Creating Apps and Components"
            echo "python manage.py startapp myapp    - Create new app"
            echo ""
            echo ">> Django REST Framework (if installed)"
            echo "# Create serializers.py in your app:"
            echo "from rest_framework import serializers"
            echo "class MyModelSerializer(serializers.ModelSerializer):"
            echo "    class Meta:"
            echo "        model = MyModel"
            echo "        fields = '__all__'"
            ;;
            
        mern|mean)
            echo ">> MERN/MEAN Stack Commands"
            echo ""
            echo "# Backend Commands"
            echo "npm start         - Start the server"
            echo "npm run dev       - Start with hot-reload (nodemon)"
            echo ""
            echo "# Frontend Commands (in client directory if separate)"
            echo "cd client && npm start  - Start React/Angular dev server"
            echo "cd client && npm build  - Build frontend for production"
            echo ""
            echo "# MongoDB Commands"
            echo "mongod           - Start MongoDB server"
            echo "mongo            - Open MongoDB shell"
            echo ""
            echo "# Full Stack Development"
            echo "# You may need to run backend and frontend in separate terminals"
            echo "# or use a tool like concurrently:"
            echo "# npm install -g concurrently"
            echo "# concurrently \"npm run server\" \"npm run client\""
            ;;
            
        *)
            log_warning "No specific commands available for ${framework}."
            echo "Common Development Commands:"
            echo "npm start         - Start the application (if Node.js based)"
            echo "npm test          - Run tests (if configured)"
            echo "npm run build     - Build for production (if configured)"
            return 1
            ;;
    esac
    
    echo ""
    log_info "These are just some common commands. Refer to the framework's documentation for more."
    return 0
}

# Parse command line arguments
function parse_args() {
    local framework=""
    
    # Process command line arguments
    for arg in "$@"; do
        case "${arg}" in
            --framework=*)
                framework="${arg#*=}"
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: ${arg}"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Show commands for framework
    show_commands "${framework}"
    return $?
}

# Execute the command
parse_args "$@"
exit $? 