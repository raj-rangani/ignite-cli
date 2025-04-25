#!/bin/bash
# =============================================
# Dependencies Command
# Handles project dependency installation
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
    log_info "Developer CLI - Dependencies Installation"
    log_info ""
    log_info "Usage: dev-cli dependencies [OPTIONS]"
    log_info ""
    log_info "Options:"
    log_info "  --framework=NAME     Specify the framework to use"
    log_info "  -h, --help           Show this help message"
    log_info ""
    log_info "Examples:"
    log_info "  dev-cli dependencies"
    log_info "  dev-cli dependencies --framework=nodejs"
}

# Function to install project dependencies
function install_project_dependencies() {
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
    
    log_info "Installing dependencies for ${framework}..."
    
    case "${framework}" in
        react|angular|vue|nodejs|mern|mean)
            log_info "Installing npm dependencies..."
            if command -v npm &> /dev/null; then
                npm install
                
                if [[ "${framework}" == "angular" ]] && ! command -v ng &> /dev/null; then
                    log_info "Installing Angular CLI..."
                    npm install -g @angular/cli
                fi
                
                if [[ "${framework}" == "vue" ]] && ! command -v vue &> /dev/null; then
                    log_info "Installing Vue CLI..."
                    npm install -g @vue/cli
                fi
            else
                log_error "npm not found. Please install Node.js and npm."
                return 1
            fi
            ;;
        flutter|react-native)
            if [[ "${framework}" == "flutter" ]]; then
                log_info "Installing Flutter dependencies..."
                if command -v flutter &> /dev/null; then
                    flutter pub get
                else
                    log_error "Flutter not found. Please install Flutter SDK."
                    return 1
                fi
            else
                log_info "Installing React Native dependencies..."
                if command -v npm &> /dev/null; then
                    npm install
                else
                    log_error "npm not found. Please install Node.js and npm."
                    return 1
                fi
            fi
            ;;
        laravel|laravel-vue)
            log_info "Installing Composer dependencies..."
            if command -v composer &> /dev/null; then
                composer install
                
                if [[ "${framework}" == "laravel-vue" ]]; then
                    log_info "Installing npm dependencies for Vue.js..."
                    if command -v npm &> /dev/null; then
                        npm install
                    else
                        log_warning "npm not found. Vue.js dependencies were not installed."
                    fi
                fi
            else
                log_error "Composer not found. Please install Composer."
                return 1
            fi
            ;;
        django)
            log_info "Installing Python dependencies..."
            if command -v pip &> /dev/null; then
                if [ -f "requirements.txt" ]; then
                    pip install -r requirements.txt
                elif [ -f "Pipfile" ]; then
                    if command -v pipenv &> /dev/null; then
                        pipenv install
                    else
                        log_warning "Pipenv not found. Cannot install dependencies from Pipfile."
                        return 1
                    fi
                else
                    log_warning "No requirements.txt or Pipfile found."
                    log_info "Creating a basic requirements.txt file..."
                    echo "django>=4.0.0,<5.0.0" > requirements.txt
                    echo "djangorestframework>=3.13.0,<4.0.0" >> requirements.txt
                    pip install -r requirements.txt
                fi
            else
                log_error "pip not found. Please install Python and pip."
                return 1
            fi
            ;;
        *)
            log_warning "Unknown framework: ${framework}. Cannot install dependencies."
            return 1
            ;;
    esac
    
    log_success "Dependencies installed successfully!"
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
    
    # Install dependencies
    install_project_dependencies "${framework}"
    return $?
}

# Execute the command
parse_args "$@"
exit $? 