#!/bin/bash
# =============================================
# Configure Command
# Handles project configuration setup
# =============================================

# Source utility scripts
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
source "${PARENT_DIR}/utils/logger.sh"
source "${PARENT_DIR}/utils/prompts.sh"
source "${PARENT_DIR}/utils/config.sh"
source "${PARENT_DIR}/utils/validators.sh"
source "${PARENT_DIR}/utils/framework.sh"

# Display help message for this command
function show_help() {
    log_info "Developer CLI - Project Configuration"
    log_info ""
    log_info "Usage: dev-cli configure [OPTIONS]"
    log_info ""
    log_info "Options:"
    log_info "  --framework=NAME     Specify the framework to use"
    log_info "  -h, --help           Show this help message"
    log_info ""
    log_info "Examples:"
    log_info "  dev-cli configure"
    log_info "  dev-cli configure --framework=nodejs"
}

# Function to configure project environment
function configure_project() {
    local framework="$1"
    
    # If DB_CONFIG_DONE is set, respect that flag
    local skip_db_config=false
    if [[ -n "${DB_CONFIG_DONE}" && "${DB_CONFIG_DONE}" == "true" ]]; then
        log_info "Database already configured in earlier step. Skipping database configuration."
        skip_db_config=true
    fi
    
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
    
    log_info "Configuring project for ${framework}..."
    
    case "${framework}" in
        react|angular|vue|nodejs|mern|mean|react-native)
            # Configure Node.js project
            if [[ ! -f ".env" && -f ".env.example" ]]; then
                log_info "Creating .env file from .env.example..."
                cp .env.example .env
                
                # Always ask for database configuration for backend projects
                if [[ "${skip_db_config}" == "false" && ("${framework}" == "nodejs" || "${framework}" == "mern" || "${framework}" == "mean") ]]; then
                    log_info "Setting up database configuration..."
                    if prompt_yesno "Would you like to configure database connection?" "y"; then
                        read -p "Database host (localhost): " db_host
                        db_host=${db_host:-localhost}
                        
                        read -p "Database port: " db_port
                        
                        read -p "Database name: " db_name
                        
                        read -p "Database user: " db_user
                        
                        read -p "Database password: " db_password
                        
                        # Check if there's already a database section in .env
                        if ! grep -q "DB_HOST" .env; then
                            echo "" >> .env
                            echo "# Database Configuration" >> .env
                        fi
                        
                        # Update existing entries or add new ones
                        sed -i '/^DB_HOST=/d' .env
                        echo "DB_HOST=${db_host}" >> .env
                        
                        if [[ -n "${db_port}" ]]; then
                            sed -i '/^DB_PORT=/d' .env
                            echo "DB_PORT=${db_port}" >> .env
                        fi
                        
                        if [[ -n "${db_name}" ]]; then
                            sed -i '/^DB_NAME=/d' .env
                            echo "DB_NAME=${db_name}" >> .env
                        fi
                        
                        if [[ -n "${db_user}" ]]; then
                            sed -i '/^DB_USER=/d' .env
                            echo "DB_USER=${db_user}" >> .env
                        fi
                        
                        if [[ -n "${db_password}" ]]; then
                            sed -i '/^DB_PASSWORD=/d' .env
                            echo "DB_PASSWORD=${db_password}" >> .env
                        fi
                        
                        # MongoDB specific configuration
                        if prompt_yesno "Are you using MongoDB?" "n"; then
                            local mongo_uri="mongodb://"
                            if [[ -n "${db_user}" && -n "${db_password}" ]]; then
                                mongo_uri="${mongo_uri}${db_user}:${db_password}@"
                            fi
                            mongo_uri="${mongo_uri}${db_host}"
                            if [[ -n "${db_port}" ]]; then
                                mongo_uri="${mongo_uri}:${db_port}"
                            fi
                            if [[ -n "${db_name}" ]]; then
                                mongo_uri="${mongo_uri}/${db_name}"
                            fi
                            sed -i '/^MONGODB_URI=/d' .env
                            echo "MONGODB_URI=${mongo_uri}" >> .env
                        fi
                    fi
                fi
                
                # Ask if user wants to edit .env
                if prompt_yesno "Would you like to edit the .env file now?" "y"; then
                    ${EDITOR:-vi} .env
                fi
            elif [[ ! -f ".env" ]]; then
                log_info "Creating .env file..."
                
                echo "# Environment Variables" > .env
                echo "NODE_ENV=development" >> .env
                
                # For Node.js add PORT
                if [[ "${skip_db_config}" == "false" && ("${framework}" == "nodejs" || "${framework}" == "mern" || "${framework}" == "mean") ]]; then
                    echo "PORT=3000" >> .env
                    echo "API_PREFIX=/api/v1" >> .env
                    
                    # Always ask for database configuration for backend projects
                    log_info "Setting up database configuration..."
                    if prompt_yesno "Would you like to configure database connection?" "y"; then
                        read -p "Database host (localhost): " db_host
                        db_host=${db_host:-localhost}
                        
                        read -p "Database port: " db_port
                        
                        read -p "Database name: " db_name
                        
                        read -p "Database user: " db_user
                        
                        read -p "Database password: " db_password
                        
                        echo "" >> .env
                        echo "# Database Configuration" >> .env
                        echo "DB_HOST=${db_host}" >> .env
                        
                        if [[ -n "${db_port}" ]]; then
                            echo "DB_PORT=${db_port}" >> .env
                        fi
                        
                        if [[ -n "${db_name}" ]]; then
                            echo "DB_NAME=${db_name}" >> .env
                        fi
                        
                        if [[ -n "${db_user}" ]]; then
                            echo "DB_USER=${db_user}" >> .env
                        fi
                        
                        if [[ -n "${db_password}" ]]; then
                            echo "DB_PASSWORD=${db_password}" >> .env
                        fi
                        
                        # MongoDB specific configuration
                        if prompt_yesno "Are you using MongoDB?" "n"; then
                            local mongo_uri="mongodb://"
                            if [[ -n "${db_user}" && -n "${db_password}" ]]; then
                                mongo_uri="${mongo_uri}${db_user}:${db_password}@"
                            fi
                            mongo_uri="${mongo_uri}${db_host}"
                            if [[ -n "${db_port}" ]]; then
                                mongo_uri="${mongo_uri}:${db_port}"
                            fi
                            if [[ -n "${db_name}" ]]; then
                                mongo_uri="${mongo_uri}/${db_name}"
                            fi
                            echo "MONGODB_URI=${mongo_uri}" >> .env
                        fi
                    fi
                fi
                
                # Ask if user wants to add more variables
                if prompt_yesno "Would you like to add more environment variables?" "n"; then
                    local continue_adding="yes"
                    while [[ "${continue_adding}" == "yes" ]]; do
                        read -p "Enter variable name: " var_name
                        read -p "Enter variable value: " var_value
                        
                        if [[ -n "${var_name}" ]]; then
                            echo "${var_name}=${var_value}" >> .env
                        fi
                        
                        if prompt_yesno "Add another variable?" "n"; then
                            continue_adding="yes"
                        else
                            continue_adding="no"
                        fi
                    done
                fi
            else
                log_info ".env file already exists."
                if prompt_yesno "Would you like to edit the existing .env file?" "n"; then
                    ${EDITOR:-vi} .env
                fi
            fi
            
            # Configure package.json scripts if they don't exist
            if [[ -f "package.json" ]]; then
                log_info "Checking package.json scripts..."
                
                if ! grep -q '"start"' package.json; then
                    log_warning "No start script found in package.json."
                    if prompt_yesno "Would you like to add basic scripts to package.json?" "y"; then
                        # Create a temporary file
                        tmp_file=$(mktemp)
                        
                        # Read package.json and add scripts
                        jq '.scripts = {"start": "node src/index.js", "dev": "nodemon src/index.js", "test": "jest"} + (.scripts // {})' package.json > "$tmp_file"
                        
                        # Check if jq command succeeded
                        if [[ $? -eq 0 ]]; then
                            mv "$tmp_file" package.json
                            log_success "Added basic scripts to package.json."
                        else
                            log_error "Failed to update package.json."
                            rm "$tmp_file"
                        fi
                    fi
                fi
            fi
            ;;
            
        flutter)
            # Configure Flutter project
            log_info "Configuring Flutter project..."
            
            if [[ -f "pubspec.yaml" ]]; then
                if prompt_yesno "Would you like to edit pubspec.yaml?" "n"; then
                    ${EDITOR:-vi} pubspec.yaml
                fi
            fi
            ;;
            
        laravel|laravel-vue)
            # Configure Laravel project
            log_info "Configuring Laravel project..."
            
            if [[ ! -f ".env" && -f ".env.example" ]]; then
                log_info "Creating .env file from .env.example..."
                cp .env.example .env
                
                # Always prompt for database configuration
                if [[ "${skip_db_config}" == "false" ]]; then
                    log_info "Setting up database configuration..."
                    if prompt_yesno "Would you like to configure database connection?" "y"; then
                        read -p "Database connection (mysql): " db_connection
                        db_connection=${db_connection:-mysql}
                        
                        read -p "Database host (localhost): " db_host
                        db_host=${db_host:-localhost}
                        
                        read -p "Database port (3306): " db_port
                        db_port=${db_port:-3306}
                        
                        read -p "Database name: " db_name
                        
                        read -p "Database user: " db_user
                        
                        read -p "Database password: " db_password
                        
                        # Update the .env file
                        sed -i "s/^DB_CONNECTION=.*/DB_CONNECTION=${db_connection}/" .env
                        sed -i "s/^DB_HOST=.*/DB_HOST=${db_host}/" .env
                        sed -i "s/^DB_PORT=.*/DB_PORT=${db_port}/" .env
                        
                        if [[ -n "${db_name}" ]]; then
                            sed -i "s/^DB_DATABASE=.*/DB_DATABASE=${db_name}/" .env
                        fi
                        
                        if [[ -n "${db_user}" ]]; then
                            sed -i "s/^DB_USERNAME=.*/DB_USERNAME=${db_user}/" .env
                        fi
                        
                        if [[ -n "${db_password}" ]]; then
                            sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=${db_password}/" .env
                        fi
                    fi
                fi
                
                # Generate application key
                if command -v php &> /dev/null; then
                    log_info "Generating application key..."
                    php artisan key:generate
                else
                    log_warning "PHP not found. Unable to generate application key."
                fi
                
                # Ask if user wants to edit .env
                if prompt_yesno "Would you like to edit the .env file now?" "y"; then
                    ${EDITOR:-vi} .env
                fi
            elif [[ ! -f ".env" ]]; then
                log_info "Creating a basic .env file manually..."
                
                echo "APP_NAME=${framework}-app" > .env
                echo "APP_ENV=local" >> .env
                echo "APP_KEY=" >> .env
                echo "APP_DEBUG=true" >> .env
                echo "APP_URL=http://localhost" >> .env
                echo "" >> .env
                echo "LOG_CHANNEL=stack" >> .env
                echo "" >> .env
                
                # Prompt for database configuration
                if [[ "${skip_db_config}" == "false" ]]; then
                    log_info "Setting up database configuration..."
                    if prompt_yesno "Would you like to configure database connection?" "y"; then
                        read -p "Database connection (mysql): " db_connection
                        db_connection=${db_connection:-mysql}
                        
                        read -p "Database host (localhost): " db_host
                        db_host=${db_host:-localhost}
                        
                        read -p "Database port (3306): " db_port
                        db_port=${db_port:-3306}
                        
                        read -p "Database name: " db_name
                        
                        read -p "Database user: " db_user
                        
                        read -p "Database password: " db_password
                        
                        echo "DB_CONNECTION=${db_connection}" >> .env
                        echo "DB_HOST=${db_host}" >> .env
                        echo "DB_PORT=${db_port}" >> .env
                        echo "DB_DATABASE=${db_name}" >> .env
                        echo "DB_USERNAME=${db_user}" >> .env
                        echo "DB_PASSWORD=${db_password}" >> .env
                    } else {
                        echo "DB_CONNECTION=mysql" >> .env
                        echo "DB_HOST=localhost" >> .env
                        echo "DB_PORT=3306" >> .env
                        echo "DB_DATABASE=laravel" >> .env
                        echo "DB_USERNAME=root" >> .env
                        echo "DB_PASSWORD=" >> .env
                    }
                fi
                
                # Generate application key
                if command -v php &> /dev/null; then
                    log_info "Generating application key..."
                    php artisan key:generate
                else
                    log_warning "PHP not found. Unable to generate application key."
                fi
                
                # Ask if user wants to edit .env
                if prompt_yesno "Would you like to edit the .env file now?" "y"; then
                    ${EDITOR:-vi} .env
                fi
            else
                log_info ".env file already exists."
                if prompt_yesno "Would you like to edit the existing .env file?" "n"; then
                    ${EDITOR:-vi} .env
                fi
                
                # Even if .env exists, ask if user wants to update database configuration
                if [[ "${skip_db_config}" == "false" ]] && prompt_yesno "Would you like to update database configuration?" "n"; then
                    read -p "Database connection (mysql): " db_connection
                    db_connection=${db_connection:-mysql}
                    
                    read -p "Database host (localhost): " db_host
                    db_host=${db_host:-localhost}
                    
                    read -p "Database port (3306): " db_port
                    db_port=${db_port:-3306}
                    
                    read -p "Database name: " db_name
                    
                    read -p "Database user: " db_user
                    
                    read -p "Database password: " db_password
                    
                    # Update the .env file
                    sed -i "s/^DB_CONNECTION=.*/DB_CONNECTION=${db_connection}/" .env
                    sed -i "s/^DB_HOST=.*/DB_HOST=${db_host}/" .env
                    sed -i "s/^DB_PORT=.*/DB_PORT=${db_port}/" .env
                    
                    if [[ -n "${db_name}" ]]; then
                        sed -i "s/^DB_DATABASE=.*/DB_DATABASE=${db_name}/" .env
                    fi
                    
                    if [[ -n "${db_user}" ]]; then
                        sed -i "s/^DB_USERNAME=.*/DB_USERNAME=${db_user}/" .env
                    fi
                    
                    if [[ -n "${db_password}" ]]; then
                        sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=${db_password}/" .env
                    fi
                }
            fi
            ;;
            
        django)
            # Configure Django project
            log_info "Configuring Django project..."
            
            # Check if settings.py exists in common locations
            local settings_file=""
            if [[ -f "settings.py" ]]; then
                settings_file="settings.py"
            elif [[ -f "config/settings.py" ]]; then
                settings_file="config/settings.py"
            elif [[ -f "app/settings.py" ]]; then
                settings_file="app/settings.py"
            elif [[ -f "project/settings.py" ]]; then
                settings_file="project/settings.py"
            else
                # Try to find settings.py
                settings_file=$(find . -name "settings.py" -not -path "*/\.*" -not -path "*/venv/*" -not -path "*/env/*" | head -n 1)
            fi
            
            if [[ -n "${settings_file}" ]]; then
                log_info "Found Django settings file: ${settings_file}"
                if prompt_yesno "Would you like to edit the settings file now?" "y"; then
                    ${EDITOR:-vi} "${settings_file}"
                fi
            else
                log_warning "Could not find Django settings.py file."
            fi
            
            # Check for .env file
            if [[ ! -f ".env" && -f ".env.example" ]]; then
                log_info "Creating .env file from .env.example..."
                cp .env.example .env
                
                # Always prompt for database configuration
                if [[ "${skip_db_config}" == "false" ]]; then
                    setup_django_database_config
                fi
                
            elif [[ ! -f ".env" ]]; then
                log_info "Creating .env file for Django project..."
                
                echo "# Django Environment Variables" > .env
                echo "DEBUG=True" >> .env
                echo "SECRET_KEY=$(python -c 'import random; print("".join([random.choice("abcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*(-_=+)") for i in range(50)]))')" >> .env
                
                # Always prompt for database configuration
                if [[ "${skip_db_config}" == "false" ]]; then
                    setup_django_database_config
                fi
                
                # Ask if user wants to add more variables
                if prompt_yesno "Would you like to add more environment variables?" "n"; then
                    local continue_adding="yes"
                    while [[ "${continue_adding}" == "yes" ]]; do
                        read -p "Enter variable name: " var_name
                        read -p "Enter variable value: " var_value
                        
                        if [[ -n "${var_name}" ]]; then
                            echo "${var_name}=${var_value}" >> .env
                        fi
                        
                        if prompt_yesno "Add another variable?" "n"; then
                            continue_adding="yes"
                        else
                            continue_adding="no"
                        fi
                    done
                fi
            else
                log_info ".env file already exists."
                if prompt_yesno "Would you like to edit the existing .env file?" "n"; then
                    ${EDITOR:-vi} .env
                fi
                
                # Even if .env exists, ask if user wants to update database configuration
                if [[ "${skip_db_config}" == "false" ]] && prompt_yesno "Would you like to update database configuration?" "n"; then
                    setup_django_database_config
                fi
            fi
            ;;
            
        *)
            log_warning "Unknown framework: ${framework}. Cannot configure project."
            return 1
            ;;
    esac
    
    log_success "Project configuration completed!"
    return 0
}

# Function to set up Django database configuration
function setup_django_database_config() {
    log_info "Setting up database configuration..."
    if prompt_yesno "Would you like to configure database connection?" "y"; then
        read -p "Database engine (postgresql): " db_engine
        db_engine=${db_engine:-postgresql}
        
        read -p "Database name: " db_name
        
        read -p "Database user: " db_user
        
        read -p "Database password: " db_password
        
        read -p "Database host (localhost): " db_host
        db_host=${db_host:-localhost}
        
        read -p "Database port (5432): " db_port
        db_port=${db_port:-5432}
        
        echo "" >> .env
        echo "# Database Configuration" >> .env
        echo "DB_ENGINE=${db_engine}" >> .env
        
        if [[ -n "${db_name}" ]]; then
            echo "DB_NAME=${db_name}" >> .env
        fi
        
        if [[ -n "${db_user}" ]]; then
            echo "DB_USER=${db_user}" >> .env
        fi
        
        if [[ -n "${db_password}" ]]; then
            echo "DB_PASSWORD=${db_password}" >> .env
        fi
        
        echo "DB_HOST=${db_host}" >> .env
        echo "DB_PORT=${db_port}" >> .env
        
        # Create DATABASE_URL for django-environ if needed
        echo "DATABASE_URL=${db_engine}://${db_user}:${db_password}@${db_host}:${db_port}/${db_name}" >> .env
        
        log_success "Database configuration added to .env file"
    fi
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
    
    # Configure project
    configure_project "${framework}"
    return $?
}

# Execute the command
parse_args "$@"
exit $? 