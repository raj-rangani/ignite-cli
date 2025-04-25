#!/bin/bash

# =============================================
# Developer CLI Tool
# Main Entry Point
# =============================================

# Set script to exit immediately if a command exits with a non-zero status
# set -e
# Instead, we'll handle errors explicitly

# Get the directory of the script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

# Source utility functions
source "$PARENT_DIR/src/utils/logger.sh"
source "$PARENT_DIR/src/utils/validators.sh"
source "$PARENT_DIR/src/utils/config.sh"
source "$PARENT_DIR/src/utils/git.sh"
source "$PARENT_DIR/src/utils/shell.sh"
source "$PARENT_DIR/src/utils/prompts.sh"

# Flag to track if database configuration has been done
DB_CONFIG_DONE=false

# Use more secure locations for log files (create log directory if it doesn't exist)
LOG_DIR="${HOME}/.dev-cli/logs"
mkdir -p "${LOG_DIR}"

DEBUG_LOG_FILE="${LOG_DIR}/dev-cli-debug.log"
ERROR_LOG_FILE="${LOG_DIR}/dev-cli-error.log"
STEP_LOG_FILE="${LOG_DIR}/dev-cli-steps.log"
INFO_LOG_FILE="${LOG_DIR}/dev-cli-info.log"

# Temporary files tracking array
declare -a TEMP_FILES=()

# Initialize log files
> "${DEBUG_LOG_FILE}"
> "${ERROR_LOG_FILE}"
> "${STEP_LOG_FILE}"
> "${INFO_LOG_FILE}"

# Enhanced function to log detailed step information
function log_step() {
    local step_num="$1"
    local message="$2"
    local status="$3"  # 'start', 'progress', 'complete', 'failed'
    
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local upper_status=$(echo "$status" | tr '[:lower:]' '[:upper:]')
    echo "[STEP ${step_num}][${upper_status}][${timestamp}] ${message}" | tee -a "${STEP_LOG_FILE}"
    
    # Also log to debug file for comprehensive logging
    log_debug "STEP ${step_num} ${upper_status}: ${message}"
}

# Enhanced error logging function
function log_debug() {
    echo "[DEBUG] $(date +"%Y-%m-%d %H:%M:%S") - $1" | tee -a "${DEBUG_LOG_FILE}"
}

function log_info() {
    echo "[INFO] $1" | tee -a "${INFO_LOG_FILE}"
}

function log_error() {
    echo "[ERROR] $(date +"%Y-%m-%d %H:%M:%S") - $1" | tee -a "${ERROR_LOG_FILE}"
}

function log_warning() {
    echo "[WARNING] $1" | tee -a "${INFO_LOG_FILE}"
}

function log_success() {
    echo "[SUCCESS] $1" | tee -a "${INFO_LOG_FILE}"
}

function log_section() {
    echo ""
    echo "=== $1 ==="
    echo ""
}

function log_critical_error() {
    echo "[CRITICAL ERROR] $(date +"%Y-%m-%d %H:%M:%S") - $1" | tee -a "${ERROR_LOG_FILE}"
    echo "[CRITICAL ERROR] Call stack:" | tee -a "${ERROR_LOG_FILE}"
    
    # Get call stack (bash 4+)
    local i=0
    while caller $i >/dev/null 2>&1; do
        local frame=$(caller $i)
        echo "  #$i: ${frame}" | tee -a "${ERROR_LOG_FILE}"
        ((i++))
    done
    
    # Capture directory state
    echo "[CRITICAL ERROR] Current directory: $(pwd)" | tee -a "${ERROR_LOG_FILE}"
    echo "[CRITICAL ERROR] Directory contents:" | tee -a "${ERROR_LOG_FILE}"
    ls -la | tee -a "${ERROR_LOG_FILE}"
}

# Safely execute commands without using eval (security improvement)
function run_command() {
    local cmd="$1"
    local step="$2"
    local description="${3:-Executing command}"
    
    log_step_progress "${description}: ${cmd}"
    log_debug "Running command at step ${step}: ${cmd}"
    
    # Execute the command and capture output and exit code
    local output
    # Use bash to execute the command instead of eval for better security
    output=$(bash -c "${cmd}" 2>&1)
    local exit_code=$?
    
    # Log command output, but mask sensitive data
    local sanitized_output=$(echo "${output}" | sed 's/password=[^[:space:]&]*/password=*****/' | sed 's/DB_PASSWORD=[^[:space:]&]*/DB_PASSWORD=****/' )
    echo "${sanitized_output}" >> "${DEBUG_LOG_FILE}"
    
    if [[ ${exit_code} -ne 0 ]]; then
        log_critical_error "Command failed at step ${step} with exit code ${exit_code}: ${cmd}"
        log_critical_error "Command output: ${sanitized_output}"
        log_step "${step}" "Command failed: ${cmd}" "failed"
        return ${exit_code}
    fi
    
    log_step_progress "Command completed successfully"
    return 0
}

# Function to track and log step transitions
function track_step() {
    local step_num="$1"
    local step_name="$2"
    
    # Update current step variable
    CURRENT_STEP="${step_num}"
    
    # Enhanced step logging with dedicated step log
    log_step "${step_num}" "Starting ${step_name}" "start"
    
    # Create a step marker file with absolute path
    if [[ -d "${MARKER_DIR}" ]]; then
        local marker_file="${MARKER_DIR}/step${step_num}_start"
        touch "${marker_file}"
        TEMP_FILES+=("${marker_file}")
        log_debug "Created step marker: ${marker_file}"
    else
        log_warning "Marker directory ${MARKER_DIR} does not exist. Creating it."
        mkdir -p "${MARKER_DIR}" || { log_error "Failed to create marker directory: ${MARKER_DIR}"; return 1; }
        local marker_file="${MARKER_DIR}/step${step_num}_start"
        touch "${marker_file}" || { log_error "Failed to create marker file: ${marker_file}"; return 1; }
        TEMP_FILES+=("${marker_file}")
        log_debug "Created step marker: ${marker_file}"
    fi
    
    # Log to standard output for user visibility
    log_section "STEP ${CURRENT_STEP}: ${step_name}"
}

# Enhanced function to log progress within a step
function log_step_progress() {
    local message="$1"
    log_step "${CURRENT_STEP}" "${message}" "progress"
}

function finish_step() {
    local step_num="$1"
    local status="${2:-complete}"  # Default to 'complete', can be 'failed'
    
    # Enhanced step completion logging
    log_step "${step_num}" "Finished ${STEP_NAMES[${step_num}]:-Unknown}" "${status}"
    
    # Create a step completion marker file with absolute path
    if [[ -d "${MARKER_DIR}" ]]; then
        local marker_file="${MARKER_DIR}/step${step_num}_${status}"
        touch "${marker_file}"
        TEMP_FILES+=("${marker_file}")
        log_debug "Created step ${status} marker: ${marker_file}"
    else
        log_warning "Marker directory ${MARKER_DIR} does not exist. Creating it."
        mkdir -p "${MARKER_DIR}" || { log_error "Failed to create marker directory: ${MARKER_DIR}"; return 1; }
        local marker_file="${MARKER_DIR}/step${step_num}_${status}"
        touch "${marker_file}" || { log_error "Failed to create marker file: ${marker_file}"; return 1; }
        TEMP_FILES+=("${marker_file}")
        log_debug "Created step ${status} marker: ${marker_file}"
    fi
    
    # Log completion status and prepare for next step
    log_debug "Step ${step_num} ${status}. Moving to next step."
}

# Add a trap for unexpected exits
trap 'log_critical_error "Script exited unexpectedly at step ${CURRENT_STEP}"; exit 1' ERR

# Function to handle interruptions and cleanup
function cleanup() {
    log_debug "Performing cleanup..."
    
    # Clean up all registered temporary files
    for temp_file in "${TEMP_FILES[@]}"; do
        if [[ -f "${temp_file}" ]]; then
            log_debug "Removing temporary file: ${temp_file}"
            rm -f "${temp_file}"
        fi
    done
    
    # Check for additional common temp files
    if [[ -f "/tmp/fixed_configure.sh" ]]; then
        log_debug "Removing /tmp/fixed_configure.sh"
        rm -f "/tmp/fixed_configure.sh"
    fi
    
    if [[ -f "/tmp/configure_errors" ]]; then
        log_debug "Removing /tmp/configure_errors"
        rm -f "/tmp/configure_errors"
    fi
    
    # Print logs on error
    if [[ $1 -ne 0 ]]; then
        log_debug "Error occurred. See logs at ${DEBUG_LOG_FILE} and ${ERROR_LOG_FILE}"
        echo "Error logs have been written to ${DEBUG_LOG_FILE} and ${ERROR_LOG_FILE}"
    fi
}

# Register cleanup on exit
trap 'cleanup $?' EXIT

# Make source command more robust
function safe_source() {
    local script="$1"
    local args=("${@:2}")  # Store args as array for safer handling
    local current_step="${CURRENT_STEP}"
    
    log_step_progress "Sourcing script: ${script} ${args[*]}"
    log_debug "Sourcing script at step ${current_step}: ${script} ${args[*]}"
    
    # Check if file exists
    if [[ ! -f "${script}" ]]; then
        log_critical_error "Source file not found: ${script}"
        log_step "${current_step}" "Source file not found: ${script}" "failed"
        return 1
    fi
    
    # Check script syntax first
    if ! check_script_syntax "${script}"; then
        log_warning "Script ${script} has syntax errors, attempting to continue..."
        log_step_progress "Script has syntax errors, attempting to continue..."
        # Try to source it anyway, with error handling
        (source "${script}" "${args[@]}") || {
            log_critical_error "Error sourcing script: ${script}"
            log_step "${current_step}" "Error sourcing script: ${script}" "failed"
            return 1
        }
    else
        # Source the script if syntax check passes
        source "${script}" "${args[@]}"
    fi
    
    local result=$?
    
    if [[ ${result} -ne 0 ]]; then
        log_critical_error "Sourced script failed at step ${current_step}: ${script} ${args[*]} (exit code ${result})"
        log_step "${current_step}" "Sourced script failed: ${script}" "failed"
        return ${result}
    fi
    
    log_step_progress "Successfully sourced script: ${script}"
    return 0
}

# Add this function to handle errors without exiting the script
function handle_error() {
    local exit_code=$1
    local command=$2
    
    if [[ $exit_code -ne 0 ]]; then
        log_error "Command failed with exit code $exit_code: $command"
        log_warning "Attempting to continue with the workflow..."
        return 1
    fi
    return 0
}

# Show help message
function show_help {
    log_info "Developer CLI Tool - Streamline your development environment setup"
    log_info ""
    log_info "Usage: dev-cli [COMMAND] [OPTIONS]"
    log_info ""
    log_info "Commands:"
    log_info "  start             Start the guided project setup workflow"
    log_info "  developer         Select your developer role"
    log_info "  framework         Select a framework for your role"
    log_info "  clone            Clone a Git repository"
    log_info "  structure         Generate project structure"
    log_info "  configure         Configure framework settings"
    log_info "  dependencies      Install project dependencies"
    log_info "  commands          Show useful commands for the selected framework"
    log_info "  flutter           Flutter-specific operations (flavors, etc.)"
    log_info "  logs              View logs (options: debug|error|info|step|all) [num_lines]"
    log_info ""
    log_info "Options:"
    log_info "  -h, --help        Show this help message"
    log_info "  -v, --version     Show version information"
    log_info "  --debug           Enable debug mode for verbose logging"
    log_info ""
    log_info "Examples:"
    log_info "  dev-cli start"
    log_info "  dev-cli developer --role=mobile"
    log_info "  dev-cli flutter flavors --flavors=dev,qa,uat,prod"
    log_info "  dev-cli logs error 100"
}

# Show version information
function show_version {
    log_info "Developer CLI Tool v1.0.0"
}

# Create a function to generate the default .env file content
function generate_default_env_file() {
    local framework="$1"
    local target_file="$2"
    local is_production="${3:-false}"
    
    log_debug "Generating default .env file for ${framework} (production=${is_production})"
    
    # Create basic configuration
    {
        echo "# Environment Configuration" 
        echo "NODE_ENV=${is_production:+production}${is_production:-development}"
    } > "${target_file}"
    
    if [[ "${framework}" == "nodejs" || "${framework}" == "mern" || "${framework}" == "mean" ]]; then
        {
            echo "PORT=3000"
            echo "API_PREFIX=/api/v1"
            
            # Add default database configuration for Node.js
            echo "" 
            echo "# Database Configuration"
            echo "DB_HOST=localhost"
            echo "DB_PORT=5432"
            echo "DB_NAME=${framework}_db"
            echo "DB_USER=dbuser"
            
            # Generate a random password instead of hardcoded default
            local random_password
            if [[ "${is_production}" == "true" ]]; then
                random_password=$(openssl rand -base64 12)
            else
                random_password="dev_password"
            fi
            echo "DB_PASSWORD=${random_password}"
            
            # Add JWT Secret for auth - always use a secure random value
            echo ""
            echo "# JWT Configuration"
            # Generate a strong random JWT secret
            local jwt_secret
            jwt_secret=$(openssl rand -hex 32)
            echo "JWT_SECRET=${jwt_secret}"
            echo "JWT_EXPIRES_IN=24h"
            
            # Add other common configuration
            echo ""
            echo "# Application Settings"
            echo "APP_NAME=${framework}-api"
            echo "LOG_LEVEL=${is_production:+info}${is_production:-debug}"
        } >> "${target_file}"
    fi
    
    if [[ "${framework}" == "react" || "${framework}" == "vue" || "${framework}" == "angular" ]]; then
        # Frontend-specific configuration
        {
            echo "REACT_APP_API_URL=http://localhost:3000/api"
            echo "VUE_APP_API_URL=http://localhost:3000/api" 
            echo "NG_APP_API_URL=http://localhost:3000/api"
        } >> "${target_file}"
    fi
    
    log_success "Created .env file with secure default configuration"
    return 0
}

# Function to install project dependencies
function install_dependencies {
    log_debug "Entering install_dependencies function. DB_CONFIG_DONE=${DB_CONFIG_DONE}"
    local framework=$(get_config "SELECTED_FRAMEWORK")
    
    if [[ -z "${framework}" ]]; then
        log_warning "No framework selected. Cannot install dependencies."
        return 1
    fi
    
    log_info "Installing dependencies for ${framework}..."
    
    # Use detect_package_manager to determine the appropriate command
    local package_manager
    package_manager=$(detect_package_manager)
    log_debug "Detected package manager: ${package_manager}"
    
    case "${framework}" in
        react|angular|vue|nodejs|mern|mean)
            if [[ "${package_manager}" == "yarn" ]]; then
                log_info "Using yarn to install dependencies..."
                run_command "yarn install" "${CURRENT_STEP}" "Installing dependencies with yarn" || {
                    log_warning "Yarn install failed, falling back to npm..."
                    run_command "npm install" "${CURRENT_STEP}" "Installing dependencies with npm (fallback)"
                }
            elif [[ "${package_manager}" == "pnpm" ]]; then
                log_info "Using pnpm to install dependencies..."
                run_command "pnpm install" "${CURRENT_STEP}" "Installing dependencies with pnpm" || {
                    log_warning "PNPM install failed, falling back to npm..."
                    run_command "npm install" "${CURRENT_STEP}" "Installing dependencies with npm (fallback)"
                }
            elif [[ "${package_manager}" == "npm" || "${package_manager}" == "unknown" ]]; then
                if command -v npm &> /dev/null; then
                    log_info "Using npm to install dependencies..."
                    run_command "npm install" "${CURRENT_STEP}" "Installing dependencies with npm"
                else
                    log_error "npm not found. Please install Node.js and npm."
                    return 1
                fi
            fi
            ;;
        flutter)
            if command -v flutter &> /dev/null; then
                log_info "Using flutter to install dependencies..."
                run_command "flutter pub get" "${CURRENT_STEP}" "Installing dependencies with flutter"
            else
                log_error "Flutter not found. Please install Flutter SDK."
                return 1
            fi
            ;;
        laravel)
            if command -v composer &> /dev/null; then
                log_info "Using composer to install dependencies..."
                run_command "composer install" "${CURRENT_STEP}" "Installing dependencies with composer"
            else
                log_error "Composer not found. Please install Composer."
                return 1
            fi
            ;;
        django)
            if command -v pip &> /dev/null; then
                log_info "Using pip to install dependencies..."
                if [[ -f "requirements.txt" ]]; then
                    run_command "pip install -r requirements.txt" "${CURRENT_STEP}" "Installing dependencies with pip"
                else
                    log_warning "No requirements.txt found. Skipping pip installation."
                fi
            else
                log_error "pip not found. Please install Python and pip."
                return 1
            fi
            ;;
        *)
            log_warning "Unknown framework: ${framework}. Attempting generic dependency installation..."
            if [[ -f "package.json" ]]; then
                log_info "Found package.json. Installing with npm..."
                run_command "npm install" "${CURRENT_STEP}" "Installing dependencies with npm"
            elif [[ -f "composer.json" ]]; then
                log_info "Found composer.json. Installing with composer..."
                run_command "composer install" "${CURRENT_STEP}" "Installing dependencies with composer"
            elif [[ -f "requirements.txt" ]]; then
                log_info "Found requirements.txt. Installing with pip..."
                run_command "pip install -r requirements.txt" "${CURRENT_STEP}" "Installing dependencies with pip"
            else
                log_error "No known dependency file found. Cannot install dependencies."
                return 1
            fi
            ;;
    esac
    
    # Check if .env file needs to be created
    if [[ ! -f ".env" ]] && [[ "${DB_CONFIG_DONE}" != "true" ]]; then
        log_info "Creating default .env file after dependency installation..."
        generate_default_env_file "${framework}" ".env"
        
        DB_CONFIG_DONE=true
        export DB_CONFIG_DONE
        log_debug "DB_CONFIG_DONE set to true after creating .env in install_dependencies"
    else
        log_debug "Skipping .env creation in install_dependencies: .env exists or DB_CONFIG_DONE=true"
    fi
    
    log_success "Dependencies installed successfully!"
    return 0
}

# Detect and use the appropriate package manager
function detect_package_manager() {
    if [[ -f "package.json" ]]; then
        if [[ -f "yarn.lock" ]]; then
            echo "yarn"
        elif [[ -f "pnpm-lock.yaml" ]]; then
            echo "pnpm"
        else
            echo "npm"
        fi
    elif [[ -f "composer.json" ]]; then
        echo "composer"
    elif [[ -f "pubspec.yaml" ]]; then
        echo "flutter"
    else
        echo "unknown"
    fi
}

# Function to install third-party dependencies with version control
function install_third_party_dependencies {
    log_info "Setting up third-party dependencies"
    
    local continue_adding="yes"
    local framework=$(get_config "SELECTED_FRAMEWORK")
    
    while [[ "${continue_adding}" == "yes" ]]; do
        echo ""
        read -p "Enter the name of the package you want to install (or leave empty to skip): " package_name
        
        if [[ -z "${package_name}" ]]; then
            log_info "No package specified. Skipping third-party dependencies."
            break
        fi
        
        # Validate package name (basic security check)
        if [[ ! "${package_name}" =~ ^[a-zA-Z0-9@_./-]+$ ]]; then
            log_error "Invalid package name. Package names should only contain alphanumeric characters, @, _, ., /, and -"
            continue
        fi
        
        read -p "Enter package version (leave empty for latest): " package_version
        
        # Validate version format if provided
        if [[ -n "${package_version}" && ! "${package_version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]]; then
            log_warning "Version format looks unusual. Standard format is x.y.z or x.y.z-tag"
            read -p "Continue with this version? (y/n): " confirm
            if [[ "${confirm}" != "y" && "${confirm}" != "Y" ]]; then
                continue
            fi
        fi
        
        package_spec="${package_name}"
        if [[ -n "${package_version}" ]]; then
            package_spec="${package_name}@${package_version}"
        fi
        
        # Use package manager detection for consistent installation
        local package_manager
        package_manager=$(detect_package_manager)
        
        case "${framework}" in
            react|angular|vue|nodejs|mern|mean)
                if [[ "${package_manager}" == "yarn" ]]; then
                    log_info "Installing ${package_spec} via yarn..."
                    run_command "yarn add ${package_spec}" "${CURRENT_STEP}" "Installing ${package_spec} with yarn" || {
                        log_error "Failed to install ${package_spec}. Please check package name and version."
                        continue
                    }
                elif [[ "${package_manager}" == "pnpm" ]]; then
                    log_info "Installing ${package_spec} via pnpm..."
                    run_command "pnpm add ${package_spec}" "${CURRENT_STEP}" "Installing ${package_spec} with pnpm" || {
                        log_error "Failed to install ${package_spec}. Please check package name and version."
                        continue
                    }
                else
                    log_info "Installing ${package_spec} via npm..."
                    run_command "npm install ${package_spec}" "${CURRENT_STEP}" "Installing ${package_spec} with npm" || {
                        log_error "Failed to install ${package_spec}. Please check package name and version."
                        continue
                    }
                fi
                ;;
            flutter)
                log_info "Installing ${package_name} via Flutter pub..."
                run_command "flutter pub add ${package_name}" "${CURRENT_STEP}" "Installing ${package_name} with flutter" || {
                    log_error "Failed to install ${package_name}. Please check package name and availability."
                    continue
                }
                ;;
            laravel)
                log_info "Installing ${package_name} via Composer..."
                run_command "composer require ${package_name}" "${CURRENT_STEP}" "Installing ${package_name} with composer" || {
                    log_error "Failed to install ${package_name}. Please check package name and version."
                    continue
                }
                ;;
            *)
                log_warning "Unknown framework: ${framework}. Cannot install dependencies."
                break
                ;;
        esac
        
        read -p "Do you want to add another package? (yes/no): " continue_adding
        continue_adding=$(echo "${continue_adding}" | tr '[:upper:]' '[:lower:]')
        
        if [[ "${continue_adding}" != "yes" && "${continue_adding}" != "y" ]]; then
            continue_adding="no"
        else
            continue_adding="yes"
        fi
    done
    
    log_success "Third-party dependencies setup completed!"
}

# Function to set up environment configurations with security guidance
function setup_environment {
    local framework=$(get_config "SELECTED_FRAMEWORK")
    
    if [[ -z "${framework}" ]]; then
        log_warning "No framework selected. Cannot set up environment."
        return 1
    fi
    
    log_info "Setting up environment configuration for ${framework}..."
    
    # Determine if this is a production environment
    local is_production=false
    read -p "Is this a production environment? (yes/no): " prod_env
    if [[ "${prod_env}" == "yes" || "${prod_env}" == "y" ]]; then
        is_production=true
        log_warning "For production environments, consider these security best practices:"
        log_info "1. Use a strong, unique JWT_SECRET (at least 32 characters)"
        log_info "2. Store sensitive credentials in a secure vault service"
        log_info "3. Set up proper access controls for database users"
        log_info "4. Enable HTTPS and set secure headers"
        log_info "5. Implement rate limiting for API endpoints"
        log_info "6. Set up proper logging and monitoring"
    fi
    
    case "${framework}" in
        react|angular|vue|nodejs|mern|mean)
            # Check if .env file exists, if not create it
            if [[ ! -f .env ]]; then
                log_info "Creating .env file..."
                generate_default_env_file "${framework}" ".env" "${is_production}"
                
                read -p "Would you like to add API endpoint URL? (yes/no): " add_api
                if [[ "${add_api}" == "yes" || "${add_api}" == "y" ]]; then
                    read -p "Enter API URL: " api_url
                    # Validate the URL format
                    if [[ "${api_url}" =~ ^https?:// ]]; then
                        echo "API_URL=${api_url}" >> .env
                    else
                        log_warning "URL should start with http:// or https://"
                        read -p "Continue anyway? (yes/no): " continue_anyway
                        if [[ "${continue_anyway}" == "yes" || "${continue_anyway}" == "y" ]]; then
                            echo "API_URL=${api_url}" >> .env
                        fi
                    fi
                fi
                
                read -p "Would you like to set up additional environment variables? (yes/no): " add_vars
                if [[ "${add_vars}" == "yes" || "${add_vars}" == "y" ]]; then
                    local continue_adding="yes"
                    while [[ "${continue_adding}" == "yes" ]]; do
                        read -p "Enter variable name: " var_name
                        # Remove validation for variable name format
                        
                        read -p "Enter variable value: " var_value
                        echo "${var_name}=${var_value}" >> .env
                        
                        read -p "Add another variable? (yes/no): " continue_adding
                        continue_adding=$(echo "${continue_adding}" | tr '[:upper:]' '[:lower:]')
                        
                        if [[ "${continue_adding}" != "yes" && "${continue_adding}" != "y" ]]; then
                            continue_adding="no"
                        else
                            continue_adding="yes"
                        fi
                    done
                fi
            else
                log_info ".env file already exists."
                read -p "Would you like to edit the existing .env file? (yes/no): " edit_env
                if [[ "${edit_env}" == "yes" || "${edit_env}" == "y" ]]; then
                    # Open with default editor or vi as fallback
                    ${EDITOR:-vi} .env
                fi
            fi
            
            # For production, check JWT Secret strength if it exists
            if [[ "${is_production}" == "true" ]]; then
                if grep -q "JWT_SECRET" .env; then
                    local jwt_secret=$(grep "JWT_SECRET" .env | cut -d= -f2)
                    if [[ ${#jwt_secret} -lt 32 ]]; then
                        log_warning "JWT_SECRET is less than 32 characters long. This is insecure for production."
                        read -p "Would you like to generate a strong JWT_SECRET? (yes/no): " regen_jwt
                        if [[ "${regen_jwt}" == "yes" || "${regen_jwt}" == "y" ]]; then
                            local secure_jwt_secret=$(openssl rand -hex 32)
                            # Replace existing JWT_SECRET line
                            sed -i "s/JWT_SECRET=.*/JWT_SECRET=${secure_jwt_secret}/" .env
                            log_success "Generated secure JWT_SECRET for production environment"
                        fi
                    fi
                fi
            fi
            ;;
        flutter)
            log_info "Flutter uses pubspec.yaml for configuration."
            read -p "Would you like to edit pubspec.yaml? (yes/no): " edit_pubspec
            if [[ "${edit_pubspec}" == "yes" || "${edit_pubspec}" == "y" ]]; then
                ${EDITOR:-vi} pubspec.yaml
            fi
            ;;
        laravel)
            log_info "Laravel uses .env for configuration."
            if [[ ! -f .env && -f .env.example ]]; then
                log_info "Creating .env file from .env.example..."
                cp .env.example .env
                
                # For production, replace APP_DEBUG=true with APP_DEBUG=false
                if [[ "${is_production}" == "true" ]]; then
                    sed -i 's/APP_DEBUG=true/APP_DEBUG=false/' .env
                    log_info "Set APP_DEBUG=false for production environment"
                fi
            fi
            
            read -p "Would you like to edit the .env file? (yes/no): " edit_env
            if [[ "${edit_env}" == "yes" || "${edit_env}" == "y" ]]; then
                ${EDITOR:-vi} .env
            fi
            
            log_info "Running Laravel key generation..."
            run_command "php artisan key:generate" "${CURRENT_STEP}" "Generating application key for Laravel"
            
            if [[ "${is_production}" == "true" ]]; then
                log_info "Optimizing Laravel for production..."
                run_command "php artisan config:cache" "${CURRENT_STEP}" "Caching configuration"
                run_command "php artisan route:cache" "${CURRENT_STEP}" "Caching routes"
                log_success "Laravel optimized for production"
            fi
            ;;
        *)
            log_warning "Unknown framework: ${framework}. Cannot set up environment."
            return 1
            ;;
    esac
    
    log_success "Environment configuration completed!"
    return 0
}

# Function to set up database configuration in .env file
function setup_db_configuration() {
    # Add this line to log when we're entering this function
    log_debug "Entering setup_db_configuration function. DB_CONFIG_DONE=${DB_CONFIG_DONE}"
    
    local framework=$(get_config "SELECTED_FRAMEWORK")
    local force_configuration="${1:-false}"
    
    # Skip if already configured in this session and not forcing reconfiguration
    if [[ "${DB_CONFIG_DONE}" == "true" && "${force_configuration}" != "true" ]]; then
        log_info "Database configuration already completed in this session."
        log_debug "Skipping DB configuration as DB_CONFIG_DONE is true and not forcing"
        return 0
    fi
    
    # For backend frameworks, we require database configuration
    local is_backend=false
    if [[ "${framework}" == "nodejs" || "${framework}" == "laravel" || "${framework}" == "django" ]]; then
        is_backend=true
    fi
    
    # Common function to get and validate database credentials
    function get_db_credentials() {
        # Get common database details with defaults
        read -p "Database host (default: localhost): " db_host
        db_host=${db_host:-localhost}
        
        read -p "Database port (default: 5432): " db_port
        db_port=${db_port:-5432}
        
        # Validate port number
        if ! [[ "${db_port}" =~ ^[0-9]+$ ]] || [[ "${db_port}" -lt 1 ]] || [[ "${db_port}" -gt 65535 ]]; then
            log_warning "Invalid port number. Port must be between 1 and 65535."
            read -p "Port (1-65535): " db_port
            # If still invalid, use default
            if ! [[ "${db_port}" =~ ^[0-9]+$ ]] || [[ "${db_port}" -lt 1 ]] || [[ "${db_port}" -gt 65535 ]]; then
                log_warning "Using default port 5432."
                db_port=5432
            fi
        fi
        
        read -p "Database name (default: ${framework}_db): " db_name
        db_name=${db_name:-${framework}_db}
        
        read -p "Database user (default: dbuser): " db_user
        db_user=${db_user:-dbuser}
        
        # For password, we don't echo input and generate a secure one
        read -p "Database password (leave empty to generate a secure one): " -s db_password
        echo # Add newline after password input
        
        # Generate secure password if empty
        if [[ -z "${db_password}" ]]; then
            db_password=$(openssl rand -base64 12)
            log_info "Generated secure database password. Make sure to save it."
            echo "Generated password: ${db_password}"
        fi
        
        # Return values in global variables
        DB_HOST="${db_host}"
        DB_PORT="${db_port}"
        DB_NAME="${db_name}"
        DB_USER="${db_user}"
        DB_PASSWORD="${db_password}"
    }
    
    # For backend projects, we ALWAYS prompt for database configuration
    if [[ "${is_backend}" == "true" ]]; then
        log_info "Database configuration is required for ${framework} projects."
        echo ""
        echo "Please provide database connection details:"
        echo ""
        
        # Get database credentials
        get_db_credentials
        
        # Create .env file if it doesn't exist
        if [[ ! -f ".env" ]]; then
            log_info "Creating .env file..."
            generate_default_env_file "${framework}" ".env"
        fi
        
        # Add to .env file - always overwrite existing database config
        # First check if there's an existing DB config section and create temp file
        local env_temp=$(mktemp)
        TEMP_FILES+=("${env_temp}")
        
        if grep -q "# Database Configuration" .env; then
            log_info "Updating existing database configuration..."
            # Copy all lines before the database section to temp file
            sed '/# Database Configuration/,$d' .env > "${env_temp}" || true
        else
            # Just copy the entire file for appending
            cp .env "${env_temp}"
        fi
        
        # Now add the new database configuration
        {
            echo ""
            echo "# Database Configuration"
            echo "DB_HOST=${DB_HOST}"
            echo "DB_PORT=${DB_PORT}"
            echo "DB_NAME=${DB_NAME}"
            echo "DB_USER=${DB_USER}"
            echo "DB_PASSWORD=${DB_PASSWORD}"
        } >> "${env_temp}"
        
        # Framework-specific environment variables
        case "${framework}" in
            nodejs)
                # Add other essential Node.js configuration if not already present
                if ! grep -q "JWT_SECRET" "${env_temp}"; then
                    {
                        echo ""
                        echo "# JWT Configuration"
                        echo "JWT_SECRET=$(openssl rand -hex 32)"
                        echo "JWT_EXPIRES_IN=24h"
                    } >> "${env_temp}"
                fi
                
                if ! grep -q "APP_NAME" "${env_temp}"; then
                    {
                        echo ""
                        echo "# Application Settings"
                        echo "APP_NAME=${framework}-api"
                        echo "LOG_LEVEL=info"
                    } >> "${env_temp}"
                fi
                
                # MongoDB connection string if this is a MongoDB project
                local use_mongodb=""
                read -p "Are you using MongoDB? (y/n, default: n): " use_mongodb
                use_mongodb=$(echo "${use_mongodb}" | tr '[:upper:]' '[:lower:]')
                
                if [[ "${use_mongodb}" == "y" || "${use_mongodb}" == "yes" ]]; then
                    log_info "Setting up MongoDB connection..."
                    local mongo_uri="mongodb://"
                    
                    if [[ -n "${DB_USER}" && -n "${DB_PASSWORD}" ]]; then
                        mongo_uri="${mongo_uri}${DB_USER}:${DB_PASSWORD}@"
                    fi
                    
                    mongo_uri="${mongo_uri}${DB_HOST}"
                    
                    if [[ -n "${DB_PORT}" ]]; then
                        mongo_uri="${mongo_uri}:${DB_PORT}"
                    fi
                    
                    if [[ -n "${DB_NAME}" ]]; then
                        mongo_uri="${mongo_uri}/${DB_NAME}"
                    fi
                    
                    echo "" >> "${env_temp}"
                    echo "# MongoDB Configuration" >> "${env_temp}" 
                    echo "MONGODB_URI=${mongo_uri}" >> "${env_temp}"
                    echo "MONGODB_DB_NAME=${DB_NAME}" >> "${env_temp}"
                    
                    log_success "MongoDB configuration added to .env file"
                else
                    log_info "Skipping MongoDB configuration."
                fi
                ;;
            laravel)
                # Add Laravel-specific DB variables
                {
                    echo "DB_CONNECTION=mysql"
                    echo "DB_DATABASE=${DB_NAME}"
                    echo "DB_USERNAME=${DB_USER}"
                    echo "DB_PASSWORD=${DB_PASSWORD}"
                } >> "${env_temp}"
                ;;
            django)
                # Django typically uses different variable names
                echo "DATABASE_URL=postgres://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}" >> "${env_temp}"
                ;;
        esac
        
        # Move temp file back to .env
        mv "${env_temp}" .env
        
        # Display the generated .env file contents
        log_info "Generated .env file with the following configuration:"
        echo "-------------- .env file contents --------------"
        cat .env
        echo "------------------------------------------------"
        
        log_success "Database configuration added to .env file"
        DB_CONFIG_DONE=true
        export DB_CONFIG_DONE
        log_debug "DB configuration completed. DB_CONFIG_DONE set to true"
    # For non-backend projects, make it optional
    else
        local configure_db=""
        read -p "Would you like to configure database connection now? (y/n, default: y): " configure_db
        configure_db=$(echo "${configure_db}" | tr '[:upper:]' '[:lower:]')
        
        if [[ "${configure_db}" == "y" || "${configure_db}" == "yes" || -z "${configure_db}" ]]; then
            log_info "Setting up database configuration..."
            
            # Get database credentials
            get_db_credentials
            
            # Create .env file if it doesn't exist
            if [[ ! -f ".env" ]]; then
                log_info "Creating .env file..."
                generate_default_env_file "${framework}" ".env"
            fi
            
            # Add to .env file - always overwrite existing database config
            local env_temp=$(mktemp)
            TEMP_FILES+=("${env_temp}")
            
            if grep -q "# Database Configuration" .env; then
                log_info "Updating existing database configuration..."
                # Copy all lines before the database section to temp file
                sed '/# Database Configuration/,$d' .env > "${env_temp}" || true
            else
                # Just copy the entire file for appending
                cp .env "${env_temp}"
            fi
            
            # Now add the new database configuration
            {
                echo ""
                echo "# Database Configuration"
                echo "DB_HOST=${DB_HOST}"
                echo "DB_PORT=${DB_PORT}"
                echo "DB_NAME=${DB_NAME}"
                echo "DB_USER=${DB_USER}"
                echo "DB_PASSWORD=${DB_PASSWORD}"
            } >> "${env_temp}"
            
            # Move temp file back to .env
            mv "${env_temp}" .env
            
            # Display the generated .env file contents
            log_info "Generated .env file with the following configuration:"
            echo "-------------- .env file contents --------------"
            cat .env
            echo "------------------------------------------------"
            
            log_success "Database configuration added to .env file"
            DB_CONFIG_DONE=true
            export DB_CONFIG_DONE
            log_debug "DB configuration completed. DB_CONFIG_DONE set to true"
        fi
    fi
}

# Better input validation for repository URL
function validate_git_url() {
    local url="$1"
    if [[ -z "$url" ]]; then
        return 1
    fi
    
    # Basic pattern matching for git URLs
    if [[ "$url" =~ ^(https?|git|ssh)://[[:alnum:]_.-]+/[[:alnum:]_.-]+/[[:alnum:]_.-]+(\.git)?$ || 
          "$url" =~ ^git@[[:alnum:]_.-]+:[[:alnum:]_.-]+/[[:alnum:]_.-]+(\.git)?$ ]]; then
        return 0
    fi
    
    return 1
}

# Function to detect and fix nested directories with the same name
function fix_nested_directories() {
    log_debug "Entering fix_nested_directories function. DB_CONFIG_DONE=${DB_CONFIG_DONE}"
    
    local current_dir=$(pwd)
    local base_dir=$(basename "${current_dir}")
    local framework=$(get_config "SELECTED_FRAMEWORK")
    local os_type=$(get_os_type)
    
    log_info "Checking directory structure in: ${current_dir}"
    log_info "Base directory name: ${base_dir}"
    log_debug "Detected OS: ${os_type}"
    
    # Check if there's a directory with the same name as the current directory
    if directory_exists "${base_dir}"; then
        log_warning "Detected potential nested directory issue: ${base_dir} inside ${current_dir}"
        log_info "Checking if this is a duplicate structure..."
        
        # Check if it looks like a template (more comprehensive checks)
        if directory_exists "${base_dir}/src" || file_exists "${base_dir}/package.json" || file_exists "${base_dir}/.env.example" || 
           file_exists "${base_dir}/composer.json" || directory_exists "${base_dir}/app" || directory_exists "${base_dir}/public"; then
            log_info "Found nested project structure. Fixing directory structure..."
            
            # Create a temporary directory
            local temp_dir=""
            case "${os_type}" in
                windows)
                    # For Windows
                    temp_dir="${TEMP:-/tmp}/dev-cli-temp-$(date +%s)"
                    create_directory "${temp_dir}"
                    ;;
                *)
                    # For Unix-like OS
                    temp_dir=$(mktemp -d)
                    ;;
            esac
            
            TEMP_FILES+=("${temp_dir}")
            log_info "Created temporary directory: ${temp_dir}"
            
            # Check if the temp directory was created
            if ! directory_exists "${temp_dir}"; then
                log_error "Failed to create temporary directory. Cannot fix nested structure."
                return 1
            fi
            
            # Move all files from nested directory to temp
            log_info "Moving files from ${base_dir} to temporary directory..."
            # First check if there are any files to move
            if read_directory "${base_dir}" "true" > /dev/null 2>&1; then
                # Try to move files, handle errors based on OS
                case "${os_type}" in
                    windows)
                        # For Windows
                        execute_command "xcopy \"${base_dir}\\*\" \"${temp_dir}\\\" /E /H /Y > nul 2>&1 || cp -R \"${base_dir}\"/* \"${temp_dir}\"/ 2>/dev/null" \
                            "Failed to copy files on Windows"
                        execute_command "xcopy \"${base_dir}\\.*\" \"${temp_dir}\\\" /E /H /Y > nul 2>&1 || cp -R \"${base_dir}\"/.[!.]* \"${temp_dir}\"/ 2>/dev/null" \
                            "Failed to copy hidden files on Windows"
                        ;;
                    *)
                        # For Unix-like OS
                        if ! mv -f "${base_dir}"/* "${temp_dir}"/ 2>/dev/null; then
                            log_warning "Some regular files could not be moved"
                        fi
                        
                        # Try to move hidden files, handle errors
                        if ! mv -f "${base_dir}"/.[!.]* "${temp_dir}"/ 2>/dev/null; then
                            log_warning "Some hidden files could not be moved"
                        fi
                        ;;
                esac
            else
                log_warning "Nested directory ${base_dir} is empty"
            fi
            
            # Remove now-empty nested directory
            log_info "Removing empty nested directory: ${base_dir}"
            case "${os_type}" in
                windows)
                    # For Windows
                    execute_command "rd /s /q \"${base_dir}\" 2>nul || rmdir \"${base_dir}\" 2>/dev/null" \
                        "Failed to remove directory on Windows"
                    ;;
                *)
                    # For Unix-like OS
                    if ! rmdir "${base_dir}" 2>/dev/null; then 
                        log_error "Failed to remove directory ${base_dir}. It may not be empty."
                        # Try to list remaining files
                        log_debug "Remaining files in ${base_dir}:"
                        read_directory "${base_dir}" "true" >> "${DEBUG_LOG_FILE}"
                        return 1
                    fi
                    ;;
            esac
            
            # Move files back from temp to current directory
            log_info "Moving files from temporary directory back to ${current_dir}..."
            # First check if there are any files to move back
            if read_directory "${temp_dir}" "true" > /dev/null 2>&1; then
                # Try to move files, handle errors based on OS
                case "${os_type}" in
                    windows)
                        # For Windows
                        execute_command "xcopy \"${temp_dir}\\*\" \".\\\" /E /H /Y > nul 2>&1 || cp -R \"${temp_dir}\"/* ./ 2>/dev/null" \
                            "Failed to copy files back on Windows"
                        execute_command "xcopy \"${temp_dir}\\.*\" \".\\\" /E /H /Y > nul 2>&1 || cp -R \"${temp_dir}\"/.[!.]* ./ 2>/dev/null" \
                            "Failed to copy hidden files back on Windows"
                        ;;
                    *)
                        # For Unix-like OS
                        if ! mv -f "${temp_dir}"/* ./ 2>/dev/null; then
                            log_warning "Some regular files could not be moved back"
                        fi
                        
                        # Try to move hidden files, handle errors
                        if ! mv -f "${temp_dir}"/.[!.]* ./ 2>/dev/null; then
                            log_warning "Some hidden files could not be moved back"
                        fi
                        ;;
                esac
            else
                log_warning "Temporary directory is empty. No files to move back."
            fi
            
            # Remove temp directory
            log_info "Removing temporary directory: ${temp_dir}"
            case "${os_type}" in
                windows)
                    # For Windows
                    execute_command "rd /s /q \"${temp_dir}\" 2>nul || rmdir \"${temp_dir}\" 2>/dev/null" \
                        "Failed to remove temporary directory on Windows"
                    ;;
                *)
                    # For Unix-like OS
                    if ! rmdir "${temp_dir}" 2>/dev/null; then
                        log_warning "Failed to remove temporary directory. It may not be empty."
                        # Try to list remaining files
                        log_debug "Remaining files in ${temp_dir}:"
                        read_directory "${temp_dir}" "true" >> "${DEBUG_LOG_FILE}"
                    fi
                    ;;
            esac
            
            log_success "Fixed nested directory structure!"
        else
            log_info "Not a duplicate project structure. No changes needed."
        fi
    else
        log_info "No nested directory with the same name found."
    fi

    # Check for missing .env file for backend frameworks - ALWAYS create one for Node.js projects
    if [[ "${framework}" == "nodejs" || "${framework}" == "laravel" || "${framework}" == "django" ]] && [[ "${DB_CONFIG_DONE}" != "true" ]]; then
        
        log_debug "Checking for .env file in backend framework. DB_CONFIG_DONE=${DB_CONFIG_DONE}"
        
        # Check if we have a .env.example but no .env
        if [[ -f ".env.example" && ! -f ".env" ]]; then
            log_info "Found .env.example but no .env file. Setting up environment configuration..."
            
            # Make a copy first to avoid overwriting the original
            cp ".env.example" ".env" || {
                log_error "Failed to copy .env.example to .env"
                return 1
            }
            
            log_success "Created .env file from template."
            setup_db_configuration "true"  # Always force configuration for clarity
        # No .env and no .env.example
        elif [[ ! -f ".env" ]]; then
            log_info "No .env file found. Setting up environment configuration..."
            
            # Create a basic .env file with secure default configuration
            generate_default_env_file "${framework}" ".env"
            
            log_success "Created basic .env file with default configuration."
            
            # Ask if user wants to customize the default database configuration
            local customize_db=""
            read -p "A default database configuration has been created. Would you like to customize it? (y/n, default: y): " customize_db
            customize_db=$(echo "${customize_db}" | tr '[:upper:]' '[:lower:]')
            
            if [[ "${customize_db}" == "y" || "${customize_db}" == "yes" || -z "${customize_db}" ]]; then
                # Force reconfiguration even if DB_CONFIG_DONE is true
                setup_db_configuration "true"
            else
                log_info "Using default database configuration. You can modify the .env file later if needed."
                # We still need to set DB_CONFIG_DONE to true
                DB_CONFIG_DONE=true
                export DB_CONFIG_DONE
                log_debug "User declined custom DB config. DB_CONFIG_DONE set to true"
            fi
            log_debug "Completed environment setup. Proceeding to next step."
        fi
    fi
}

# Function to check syntax of a script before sourcing
function check_script_syntax() {
    local script_path="$1"
    
    if [[ ! -f "${script_path}" ]]; then
        log_error "Script not found: ${script_path}"
        return 1
    fi
    
    # Check bash syntax without executing
    bash -n "${script_path}"
    local result=$?
    
    if [[ ${result} -ne 0 ]]; then
        log_critical_error "Syntax error in script ${script_path}"
        # Try to identify the problematic line
        local error_output=$(bash -n "${script_path}" 2>&1)
        log_debug "Syntax check output: ${error_output}"
        return ${result}
    fi
    
    return 0
}

# Modify the start_guided_workflow function to include explicit step tracking
function start_guided_workflow {
    # Initialize step names for better logging
    declare -A STEP_NAMES
    STEP_NAMES[1]="Init and TechStack Selection"
    STEP_NAMES[2]="Framework Selection"
    STEP_NAMES[3]="Project Source"
    STEP_NAMES[4]="Project Structure"
    STEP_NAMES[5]="Environment and Database Configuration"
    STEP_NAMES[6]="Additional Environment Settings"
    STEP_NAMES[7]="Installing Dependencies"
    STEP_NAMES[8]="Useful Commands"
    STEP_NAMES[9]="Completion"
    export STEP_NAMES
    
    # Enable debug mode for verbose logging if needed
    if [[ "${DEBUG_CLI:-false}" == "true" ]]; then
        set_debug_mode "true"
    fi
    
    # Don't clear screen to maintain history
    # clear  <- Remove this line
    log_section "Ignite CLI Tool - Project Setup"
    log_info "Welcome to the project setup workflow. You will be guided through each step in sequence."
    echo ""
    
    # Initialize step tracking and create marker directory
    CURRENT_STEP=0
    MARKER_DIR="$HOME/.dev-cli-markers-$(date +%s)"
    mkdir -p "${MARKER_DIR}"
    log_debug "Created marker directory: ${MARKER_DIR}"
    
    # Reset any existing configurations for a fresh start
    set_config "DEVELOPER_ROLE" ""
    set_config "SELECTED_FRAMEWORK" ""
    
    # Step 1: TechStack Selection (Previously Developer Role Selection)
    track_step 1 "TechStack Selection"
    log_section "STEP ${CURRENT_STEP}: TechStack Selection"
    log_info "Let's start by selecting your tech stack for this project."
    
    local role=""
    while [[ -z "${role}" ]]; do
        echo "Available Tech Stacks:"
        echo "  1. Frontend"
        echo "  2. Backend"
        echo "  3. Mobile"
        echo ""
        
        read -p "Enter your choice (1-3): " role_choice
        
        case "${role_choice}" in
            1)
                role="frontend"
                ;;
            2)
                role="backend"
                ;;
            3)
                role="mobile"
                ;;
            *)
                log_error "Invalid choice. Please select a number between 1 and 3."
                role=""
                ;;
        esac
    done
    
    set_config "DEVELOPER_ROLE" "${role}"
    log_success "Tech Stack set to: ${role}"
    finish_step 1
    echo ""
    
    # Step 2: Framework Selection
    track_step 2 "Framework Selection"
    log_section "STEP ${CURRENT_STEP}: Framework Selection"
    log_info "Now, let's select the framework for your ${role} project."
    
    local framework=""
    while [[ -z "${framework}" ]]; do
        case "${role}" in
            frontend)
                echo "Available frontend frameworks:"
                echo "  1. React"
                echo "  2. Angular"
                echo "  3. Vue"
                echo ""
                
                read -p "Enter your choice (1-3): " framework_choice
                
                case "${framework_choice}" in
                    1)
                        framework="react"
                        ;;
                    2)
                        framework="angular"
                        ;;
                    3)
                        framework="vue"
                        ;;
                    *)
                        log_error "Invalid choice. Please select a number between 1 and 3."
                        ;;
                esac
                ;;
            backend)
                echo "Available backend frameworks:"
                echo "  1. Node.js (Express)"
                echo "  2. Laravel (PHP)"
                echo "  3. Django (Python)"
                echo ""
                
                read -p "Enter your choice (1-3): " framework_choice
                
                case "${framework_choice}" in
                    1)
                        framework="nodejs"
                        ;;
                    2)
                        framework="laravel"
                        ;;
                    3)
                        framework="django"
                        ;;
                    *)
                        log_error "Invalid choice. Please select a number between 1 and 3."
                        ;;
                esac
                ;;
            mobile)
                echo "Available mobile frameworks:"
                echo "  1. Flutter"
                echo "  2. React Native"
                echo ""
                
                read -p "Enter your choice (1-2): " framework_choice
                
                case "${framework_choice}" in
                    1)
                        framework="flutter"
                        ;;
                    2)
                        framework="react-native"
                        ;;
                    *)
                        log_error "Invalid choice. Please select a number between 1 and 2."
                        ;;
                esac
                ;;
        esac
    done
    
    set_config "SELECTED_FRAMEWORK" "${framework}"
    log_success "Framework set to: ${framework}"
    finish_step 2
    echo ""
    
    # Special handling for Flutter projects
    if [[ "${framework}" == "flutter" ]]; then
        # Skip Git Repository step and directly create Flutter project
        track_step 3 "Flutter Project Creation"
        log_section "STEP ${CURRENT_STEP}: Flutter Project Creation"
        log_info "Setting up a new Flutter project..."
        
        # Call the Flutter project creation implementation
        if [[ -f "$PARENT_DIR/src/commands/flutter.sh" ]]; then
            source "$PARENT_DIR/src/commands/flutter.sh" "create"
            if [[ $? -ne 0 ]]; then
                log_error "Flutter project creation failed."
                finish_step 3 "failed"
                return 1
            fi
        else
            log_error "Flutter command script not found."
            finish_step 3 "failed"
            return 1
        fi
        
        # Get the project directory that was created
        local flutter_project_name=$(get_config "FLUTTER_PROJECT_NAME")
        if [[ -n "${flutter_project_name}" && -d "${flutter_project_name}" ]]; then
            log_info "Navigating to Flutter project directory: ${flutter_project_name}"
            cd "${flutter_project_name}" || { 
                log_error "Failed to change to ${flutter_project_name} directory."; 
                finish_step 3 "failed";
                return 1; 
            }
        fi
        
        log_info "Flutter project setup completed. Current directory: $(pwd)"
        finish_step 3
        
        # Skip to Step 7 (Dependencies) as Steps 4-6 aren't applicable for new Flutter projects
        track_step 4 "Project Structure"
        log_info "Using Flutter default project structure."
        finish_step 4
        
        track_step 5 "Environment Configuration"
        log_info "Flutter projects use pubspec.yaml for configuration."
        finish_step 5
        
        track_step 6 "Additional Settings"
        log_info "No additional settings needed for new Flutter projects."
        finish_step 6
        
        # Continue with dependencies step
        track_step 7 "Installing Dependencies"
        log_section "STEP ${CURRENT_STEP}: Installing Dependencies"
        log_info "Installing dependencies for Flutter..."
        
        if [[ -f "pubspec.yaml" ]]; then
            log_info "Running flutter pub get..."
            run_command "flutter pub get" "${CURRENT_STEP}" "Installing Flutter dependencies"
            log_success "Flutter dependencies installed successfully!"
        else
            log_warning "No pubspec.yaml found. Skipping dependency installation."
        fi
        
        finish_step 7
        
        # Skip to Step 8 (Useful Commands)
        track_step 8 "Useful Commands"
        log_section "STEP ${CURRENT_STEP}: Useful Commands"
        log_info "Here are some useful Flutter commands:"
        log_info "1. flutter run - Run your Flutter app"
        log_info "2. flutter build - Build your Flutter app for production"
        log_info "3. flutter test - Run tests for your Flutter app"
        log_info "4. flutter pub add [package] - Add a package dependency"
        finish_step 8
        
        # Set the current project directory
        CURRENT_PROJECT_DIR=$(pwd)
    else
        # Regular Git Repository flow for non-Flutter projects
        track_step 3 "Project Source"
        log_section "STEP ${CURRENT_STEP}: Project Source"
        log_info "Now, provide the Git repository URL for your project."

        local repo_url=""
        while [[ -z "${repo_url}" ]]; do
            read -p "Enter Git repository URL: " repo_url
            if [[ -z "${repo_url}" ]]; then
                log_error "Repository URL cannot be empty. Please try again."
            fi
        done

        # Get parent directory of script for better path handling
        PARENT_PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
        log_info "Parent directory for project: ${PARENT_PROJECT_DIR}"

        local clone_dir=""
        read -p "Enter the directory name for cloning (leave empty for default): " clone_dir

        # Save current directory to return after check
        CURRENT_DIR=$(pwd)

        # Create a specific directory for the project in a logical location
        if [[ -z "${clone_dir}" ]]; then
            # Extract repo name from URL for default directory name
            repo_name=$(basename "${repo_url}" .git)
            clone_dir="${repo_name}"
            log_info "Using default directory name: ${clone_dir}"
        fi

        # Always use an absolute path for the project directory
        PROJECT_ROOT="${PARENT_PROJECT_DIR}/${clone_dir}"
        log_info "Project will be cloned to: ${PROJECT_ROOT}"

        # Create the directory if it doesn't exist
        if [[ ! -d "${PROJECT_ROOT}" ]]; then
            mkdir -p "${PROJECT_ROOT}"
        fi

        # Navigate to the project root and clone there
        cd "${PROJECT_ROOT}" || { log_error "Failed to change to ${PROJECT_ROOT} directory."; return 1; }

        # Before cloning, log the command that will be used
        log_debug "About to clone repository: git clone '${repo_url}' ."
        
        # Now clone into the current directory with verbose logging
        log_info "Cloning repository into ${PROJECT_ROOT}..."
        run_command "git clone '${repo_url}' . --verbose" ${CURRENT_STEP} || { 
            log_critical_error "Failed to clone repository. Check the URL and try again."; 
            cd "${CURRENT_DIR}"
            # Continue but mark step as failed
            touch "${MARKER_DIR}/step${CURRENT_STEP}_failed"
        }
        
        finish_step 3
        
        log_info "Repository setup completed. Current directory: $(pwd)"
        log_info "Contents of current directory:"
        ls -la
        
        # Run fix_nested_directories immediately after cloning
        log_info "Checking for potential directory structure issues..."
        fix_nested_directories
    fi
    
    # Step 4: Generate Project Structure
    track_step 4 "Project Structure"
    log_section "STEP ${CURRENT_STEP}: Project Structure"
    log_info "Generating project structure for ${framework}..."
    
    # Get the current directory name to avoid nesting with the same name
    current_dir_name=$(basename "$(pwd)")
    # Use a different project name if it would create a nested directory with the same name
    local structure_name="${current_dir_name}"
    local structure_dir="."  # Use current directory instead of creating a subdirectory
    
    # Call structure generator with proper error trapping
    log_debug "About to source structure generator: $PARENT_DIR/src/commands/structure.sh"
    structure_output=$(safe_source "$PARENT_DIR/src/commands/structure.sh" --framework="${framework}" --name="${structure_name}" --dir="${structure_dir}" --role="${role}" 2>&1)
    
    log_debug "Structure generator output: ${structure_output}"
    echo "$structure_output"
    
    finish_step 4
    
    # Extract project directory from output - improved pattern matching
    PROJECT_DIR=$(echo "$structure_output" | grep -o "PROJECT_DIRECTORY:.*" | sed 's/PROJECT_DIRECTORY://' | tr -d '[:space:]')
    
    if [[ -n "$PROJECT_DIR" && -d "$PROJECT_DIR" && "$PROJECT_DIR" != "$(pwd)" ]]; then
        log_info "Navigating to project directory: $PROJECT_DIR"
        cd "$PROJECT_DIR" || { log_error "Failed to change to ${PROJECT_DIR} directory."; return 1; }
    else
        log_info "Using current directory for project structure"
    fi
    
    # Record the current directory for later reference
    CURRENT_PROJECT_DIR=$(pwd)
    
    # *** REORDERED STEPS: Setup Environment and DB first, then dependencies ***
    
    # Step 5: Environment and Database Configuration
    track_step 5 "Environment and Database Configuration"
    log_section "STEP ${CURRENT_STEP}: Environment and Database Configuration"
    log_info "Setting up environment and database configuration for your ${framework} project..."
    log_debug "Beginning Step 5 with DB_CONFIG_DONE=${DB_CONFIG_DONE}"
    
    if [[ "${framework}" == "nodejs" || "${framework}" == "laravel" || "${framework}" == "django" || 
          "${framework}" == "mern" || "${framework}" == "mean" ]]; then
        
        # Always create default .env file
        if [[ ! -f ".env" ]]; then
            log_info "Creating default .env file for ${framework} project..."
            log_debug "No .env file found. Creating one with default values."
            
            echo "# Environment Configuration" > .env
            echo "NODE_ENV=development" >> .env
            
            if [[ "${framework}" == "nodejs" || "${framework}" == "mern" || "${framework}" == "mean" ]]; then
                echo "PORT=3000" >> .env
                echo "API_PREFIX=/api/v1" >> .env
                
                # Add default database configuration for Node.js
                echo "" >> .env
                echo "# Database Configuration" >> .env
                echo "DB_HOST=localhost" >> .env
                echo "DB_PORT=5432" >> .env
                echo "DB_NAME=${framework}_db" >> .env
                echo "DB_USER=dbuser" >> .env
                
                # Generate a random password instead of hardcoded default
                local random_password
                if [[ "${DB_CONFIG_DONE}" == "true" ]]; then
                    random_password=$(openssl rand -base64 12)
                else
                    random_password="dev_password"
                fi
                echo "DB_PASSWORD=${random_password}" >> .env
                
                # Add JWT Secret for auth - always use a secure random value
                echo "" >> .env
                echo "# JWT Configuration" >> .env
                # Generate a strong random JWT secret
                local jwt_secret
                jwt_secret=$(openssl rand -hex 32)
                echo "JWT_SECRET=${jwt_secret}" >> .env
                echo "JWT_EXPIRES_IN=24h" >> .env
                
                # Add other common configuration
                echo "" >> .env
                echo "# Application Settings" >> .env
                echo "APP_NAME=${framework}-api" >> .env
                echo "LOG_LEVEL=${is_production:+info}${is_production:-debug}" >> .env
            fi
            
            log_success "Created default .env file with basic Node.js configuration."
            
            # Export the DB_CONFIG_DONE flag to make it available globally
            DB_CONFIG_DONE=true
            export DB_CONFIG_DONE
            log_debug "DB_CONFIG_DONE set to true after creating default .env file"
        else
            log_info "Found existing .env file."
            log_debug "Found existing .env file. DB_CONFIG_DONE=${DB_CONFIG_DONE}"
        fi
        
        # Only ask to customize if .env was just created and DB_CONFIG_DONE is not already true
        if [[ "${DB_CONFIG_DONE}" != "true" ]]; then
            # Ask user if they want to customize the default configuration
            if prompt_yesno "Would you like to customize the default environment settings?" "n"; then
                echo "LOG_LEVEL=${is_production:+info}${is_production:-debug}" >> .env
            else
                log_info "Using default environment configuration from .env file. You can modify this file later if needed."
                DB_CONFIG_DONE=true
                export DB_CONFIG_DONE
                log_debug "DB_CONFIG_DONE set to true after declining custom config"
            fi
        else
            log_debug "Skipping DB configuration prompt as DB_CONFIG_DONE is already true"
        fi
    fi
    
    # Make sure to properly finish this step before moving on
    finish_step 5
    log_info "Environment and database configuration completed. Moving to additional settings..."

    # Check if we're working with Node.js backend project
    if [[ "${framework}" == "nodejs" || "${framework}" == "mern" || "${framework}" == "mean" || "${framework}" == "laravel" ]]; then
        # Ask if user wants to configure additional settings
        if prompt_yesno "Would you like to configure additional settings for your application (SMTP, file uploads, etc.)?" "y"; then
            log_info "Configuring additional application settings..."
            
            # SMTP Configuration
            if prompt_yesno "Do you want to configure SMTP for email sending?" "y"; then
                log_info "Please provide SMTP server details:"
                
                read -p "SMTP Host (e.g., smtp.gmail.com): " smtp_host
                read -p "SMTP Port (e.g., 465 for SSL, 587 for TLS): " smtp_port
                read -p "SMTP Username (email address): " smtp_user
                read -p "SMTP Password: " smtp_pass
                read -p "Mail From Address (usually same as SMTP Username): " mail_from
                
                # Add to .env
                echo "" >> .env
                echo "# Email Configuration" >> .env
                echo "MAIL_MAILER=smtp" >> .env
                echo "MAIL_HOST=${smtp_host}" >> .env
                echo "MAIL_PORT=${smtp_port}" >> .env
                echo "MAIL_USERNAME=${smtp_user}" >> .env
                echo "MAIL_PASSWORD=${smtp_pass}" >> .env
                echo "MAIL_FROM_ADDRESS=${mail_from}" >> .env
                echo "MAIL_ENCRYPTION=tls" >> .env
                
                log_success "SMTP configuration added to .env"
            fi
            
            # File Upload Configuration
            if prompt_yesno "Do you want to configure file upload settings?" "y"; then
                read -p "Maximum upload size in bytes (default: 5MB = 5242880): " upload_limit
                upload_limit=${upload_limit:-5242880}
                
                echo "" >> .env
                echo "# File Upload Configuration" >> .env
                echo "UPLOAD_MAX_FILESIZE=${upload_limit}" >> .env
                
                log_success "File upload configuration added to .env"
            fi
            
            # Frontend URL Configuration
            if prompt_yesno "Do you want to configure a frontend URL for CORS?" "y"; then
                read -p "Frontend URL (e.g., http://localhost:3000): " frontend_url
                
                echo "" >> .env
                echo "# Frontend Configuration" >> .env
                echo "FRONTEND_URL=${frontend_url}" >> .env
                
                log_success "Frontend URL configuration added to .env"
            fi
            
            # Application Secret Key
            if prompt_yesno "Do you want to add a custom application secret key?" "y"; then
                read -p "Application Secret Key (leave empty to generate one): " app_key
                
                if [[ -z "${app_key}" ]]; then
                    app_key=$(openssl rand -hex 16)
                fi
                
                echo "" >> .env
                echo "# Application Secret" >> .env
                echo "APP_KEY=${app_key}" >> .env
                
                log_success "Application secret key added to .env"
            fi
            
            # Any other custom environment variables
            if prompt_yesno "Do you want to add any other custom environment variables?" "y"; then
                local adding_vars="yes"
                
                # Add section header if it doesn't exist
                if ! grep -q "# Custom Environment Variables" .env; then
                    echo "" >> .env
                    echo "# Custom Environment Variables" >> .env
                fi
                
                while [[ "${adding_vars}" == "yes" ]]; do
                    # Get variable name without validation
                    read -p "Variable name: " var_name
                    
                    # Get variable value without validation
                    read -p "Variable value: " var_value
                    
                    # Add variable to .env file directly
                    echo "${var_name}=${var_value}" >> ".env"
                    log_success "Variable ${var_name} added successfully"
                    
                    if ! prompt_yesno "Add another variable?" "n"; then
                        adding_vars="no"
                    fi
                done
                
                log_success "Custom environment variables configuration completed!"
                
                # Show summary of added variables (excluding sensitive ones)
                echo "Added environment variables:"
                echo "----------------------------------------------------"
                grep "^[A-Za-z_][A-Za-z0-9_]*=" .env | grep -v "PASSWORD\|SECRET\|KEY" | 
                    sed 's/\(.*PASSWORD.*=\).*/\1********/' | 
                    sed 's/\(.*SECRET.*=\).*/\1********/' | 
                    sed 's/\(.*KEY.*=\).*/\1********/'
                echo "----------------------------------------------------"
                log_info "Note: Sensitive values have been hidden for security"
            fi
            
            # Show a summary of the configured environment
            log_info "Here's a summary of your configured environment:"
            echo "----------------------------------------------------"
            cat .env | grep -v "PASSWORD\|SECRET\|PASS" | sed 's/\(.*PASSWORD.*=\).*/\1********/' | sed 's/\(.*SECRET.*=\).*/\1********/' | sed 's/\(.*PASS.*=\).*/\1********/'
            echo "----------------------------------------------------"
            log_info "Sensitive values have been hidden for security"
            
            log_success "Additional environment configuration completed!"
        else
            log_info "Skipping additional configuration. You can manually edit .env later if needed."
        fi
    fi

    # Step 6: General Environment Configuration
    track_step 6 "Additional Environment Settings"
    log_section "STEP ${CURRENT_STEP}: Additional Environment Settings"
    log_info "Setting up additional environment configuration for ${framework}..."
    
    # Pass the DB_CONFIG_DONE flag to the configure script
    export DB_CONFIG_DONE

    # Try sourcing with error handling
    if ! source "$PARENT_DIR/src/commands/configure.sh" --framework="${framework}" 2>/tmp/configure_errors; then
        log_warning "Configure command had errors: $(cat /tmp/configure_errors)"
        log_info "Using simplified environment configuration instead..."
        
        # Simplified environment setup as fallback
        case "${framework}" in
            nodejs|mern|mean)
                # Ensure basic .env settings are present
                if [[ ! -f ".env" ]]; then
                    log_info "Creating basic .env file..."
                    echo "# Environment Configuration" > .env
                    echo "NODE_ENV=development" >> .env
                    echo "PORT=3000" >> .env
                    echo "API_PREFIX=/api/v1" >> .env
                    echo "DB_HOST=localhost" >> .env
                    echo "DB_PORT=5432" >> .env
                    echo "DB_NAME=${framework}_db" >> .env
                    echo "DB_USER=dbuser" >> .env
                    echo "DB_PASSWORD=${DB_CONFIG_DONE:+${DB_CONFIG_DONE}dev_password}${DB_CONFIG_DONE:-dev_password}" >> .env
                    echo "JWT_SECRET=$(openssl rand -hex 32)" >> .env
                    echo "JWT_EXPIRES_IN=24h" >> .env
                    echo "APP_NAME=${framework}-api" >> .env
                    echo "LOG_LEVEL=${DB_CONFIG_DONE:+info}${DB_CONFIG_DONE:-debug}" >> .env
                fi
                ;;
            react|angular|vue)
                # Frontend environment setup
                if [[ ! -f ".env" ]]; then
                    echo "# Environment Configuration" > .env
                    echo "NODE_ENV=development" >> .env
                    echo "REACT_APP_API_URL=http://localhost:3000/api" >> .env
                fi
                ;;
        esac
    fi
    
    # Properly finish step 6 with clear logging
    finish_step 6
    log_info "Additional environment settings completed. Moving to dependency installation..."

    # Step 7: Install Dependencies - Fix to ensure this step is not skipped
    track_step 7 "Installing Dependencies"
    log_section "STEP ${CURRENT_STEP}: Installing Dependencies"
    log_info "Installing dependencies for ${framework}..."

    # Fix the bad substitution error by doing the file check separately
    env_file_exists="false"
    if [[ -f ".env" ]]; then
        env_file_exists="true"
    fi
    log_debug "Beginning Step 7 with DB_CONFIG_DONE=${DB_CONFIG_DONE}, .env file exists: ${env_file_exists}"

    # Before installing dependencies, make sure .env exists (one final check)
    if [[ "${framework}" == "nodejs" || "${framework}" == "mern" || "${framework}" == "mean" ]] && [[ ! -f ".env" ]] && [[ "${DB_CONFIG_DONE}" != "true" ]]; then
        log_warning "No .env file found before dependency installation. Creating one now..."
        log_debug "Creating .env file in step 7 as none exists and DB_CONFIG_DONE=${DB_CONFIG_DONE}"
        
        # Simplified .env creation
        log_info "Creating basic .env file..."
        echo "# Environment Configuration" > .env
        echo "NODE_ENV=development" >> .env
        echo "PORT=3000" >> .env
        echo "API_PREFIX=/api/v1" >> .env
        echo "DB_HOST=localhost" >> .env
        echo "DB_PORT=5432" >> .env
        echo "DB_NAME=${framework}_db" >> .env
        echo "DB_USER=dbuser" >> .env
        echo "DB_PASSWORD=${DB_CONFIG_DONE:+${DB_CONFIG_DONE}dev_password}${DB_CONFIG_DONE:-dev_password}" >> .env
        echo "JWT_SECRET=$(openssl rand -hex 32)" >> .env
        echo "JWT_EXPIRES_IN=24h" >> .env
        echo "APP_NAME=${framework}-api" >> .env
        echo "LOG_LEVEL=${DB_CONFIG_DONE:+info}${DB_CONFIG_DONE:-debug}" >> .env
        
        # Set the flag to prevent duplicate prompts
        DB_CONFIG_DONE=true
        export DB_CONFIG_DONE
        log_debug "DB_CONFIG_DONE set to true after creating .env file in step 7"
    else
        log_debug "No need to create .env in step 7: .env file exists=${env_file_exists}, DB_CONFIG_DONE=${DB_CONFIG_DONE}"
    fi

    # DIRECT NPM INSTALL - Don't rely on detect_package_manager function
    log_info "Installing ${framework} dependencies directly..."
    case "${framework}" in
        react|angular|vue|nodejs|mern|mean)
            # Check for package.json
            if [[ -f "package.json" ]]; then
                # Check for different lock files to determine package manager
                if [[ -f "yarn.lock" ]]; then
                    log_info "Yarn lock file detected. Installing with yarn..."
                    run_command "yarn install" "${CURRENT_STEP}" "Installing dependencies with yarn" || {
                        log_warning "Yarn install failed, falling back to npm..."
                        run_command "npm install" "${CURRENT_STEP}" "Installing dependencies with npm (fallback)"
                    }
                elif [[ -f "pnpm-lock.yaml" ]]; then
                    log_info "PNPM lock file detected. Installing with pnpm..."
                    run_command "pnpm install" "${CURRENT_STEP}" "Installing dependencies with pnpm" || {
                        log_warning "PNPM install failed, falling back to npm..."
                        run_command "npm install" "${CURRENT_STEP}" "Installing dependencies with npm (fallback)"
                    }
                else
                    log_info "Installing dependencies with npm..."
                    run_command "npm install" "${CURRENT_STEP}" "Installing dependencies with npm"
                fi
            else
                log_warning "No package.json found. Cannot install dependencies."
            fi
            ;;
        laravel)
            if [[ -f "composer.json" ]]; then
                log_info "Installing dependencies with composer..."
                run_command "composer install" "${CURRENT_STEP}" "Installing dependencies with composer"
            else
                log_warning "No composer.json found. Cannot install dependencies."
            fi
            ;;
        flutter)
            if [[ -f "pubspec.yaml" ]]; then
                log_info "Installing dependencies with flutter..."
                run_command "flutter pub get" "${CURRENT_STEP}" "Installing dependencies with flutter"
            else
                log_warning "No pubspec.yaml found. Cannot install dependencies."
            fi
            ;;
        django)
            if [[ -f "requirements.txt" ]]; then
                log_info "Installing dependencies with pip..."
                run_command "pip install -r requirements.txt" "${CURRENT_STEP}" "Installing dependencies with pip"
            else
                log_warning "No requirements.txt found. Cannot install dependencies."
            fi
            ;;
        *)
            log_warning "Unknown framework: ${framework}. Trying generic dependency installation..."
            if [[ -f "package.json" ]]; then
                log_info "Found package.json. Installing with npm..."
                run_command "npm install" "${CURRENT_STEP}" "Installing dependencies with npm"
            elif [[ -f "composer.json" ]]; then
                log_info "Found composer.json. Installing with composer..."
                run_command "composer install" "${CURRENT_STEP}" "Installing dependencies with composer"
            elif [[ -f "requirements.txt" ]]; then
                log_info "Found requirements.txt. Installing with pip..."
                run_command "pip install -r requirements.txt" "${CURRENT_STEP}" "Installing dependencies with pip"
            else
                log_error "No known dependency file found. Cannot install dependencies."
            fi
            ;;
    esac

    # Explicitly mark step as complete
    log_success "Dependency installation completed!"
    finish_step 7
    log_info "Dependencies installed. Moving to useful commands..."

    # Step 8: Show Useful Commands
    track_step 8 "Useful Commands"
    log_section "STEP ${CURRENT_STEP}: Useful Commands"
    log_info "Here are some useful commands for ${framework}:"
    
    # Call command-list command directly with the selected framework
    source "$PARENT_DIR/src/commands/command-list.sh" --framework="${framework}" || {
        log_warning "Command list had errors but continuing workflow..."
    }
    
    # Check and fix any nested directory issues that might have occurred
    log_info "Checking once more for directory structure issues..."
    fix_nested_directories
    
    # Debug information before completion
    log_info "Current working directory before completion: $(pwd)"
    log_info "Directory contents before completion:"
    ls -la
    
    finish_step 8
    
    # At the end, log completion status
    log_debug "==== WORKFLOW COMPLETED ===="
    log_debug "Step completion status:"
    
    for i in {1..8}; do
        if [[ -f "${MARKER_DIR}/step${i}_complete" ]]; then
            log_debug "  Step $i: COMPLETE"
        elif [[ -f "${MARKER_DIR}/step${i}_failed" ]]; then
            log_debug "  Step $i: FAILED"
        else
            log_debug "  Step $i: NOT REACHED"
        fi
    done
    
    log_debug "Final directory: $(pwd)"
    log_debug "Final directory contents:"
    ls -la >> "${DEBUG_LOG_FILE}"
    
    finish_step 9
    
    CURRENT_STEP=9
    # Completion
    # clear  <- Remove this line
    log_section "Project Setup Complete"
    log_success "Your development environment is ready!"
    log_info "Current working directory: $(pwd)"
    
    # Show next steps
    echo ""
    log_info "Next Steps:"
    framework=$(get_config "SELECTED_FRAMEWORK")
    
    case "${framework}" in
        react)
            log_info "1. Start development server: npm start"
            log_info "2. Build for production: npm run build"
            log_info "3. Run tests: npm test"
            ;;
        angular)
            log_info "1. Start development server: ng serve"
            log_info "2. Build for production: ng build --prod"
            log_info "3. Generate components/services: ng generate"
            ;;
        vue)
            log_info "1. Start development server: npm run serve"
            log_info "2. Build for production: npm run build"
            log_info "3. Run tests: npm run test"
            ;;
        flutter)
            # Handle the flutter command directly
            shift
            # Always delegate to the flutter.sh script for all operations
            if [[ -f "$PARENT_DIR/src/commands/flutter.sh" ]]; then
                source "$PARENT_DIR/src/commands/flutter.sh" "$@"
            else
                log_error "Flutter command script not found."
                exit 1
            fi
            exit $?
            ;;
        laravel)
            log_info "1. Start development server: php artisan serve"
            log_info "2. Run migrations: php artisan migrate"
            log_info "3. Create controllers/models: php artisan make:controller"
            ;;
        nodejs)
            log_info "1. Start server: npm start"
            log_info "2. Run in development mode: npm run dev"
            log_info "3. Run tests: npm test"
            ;;
    esac
    
    echo ""
    log_info "Thank you for using Developer CLI Tool!"
}

# Main function to handle command routing
function main {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        show_help
        exit 0
    fi

    if [[ "$1" == "-v" || "$1" == "--version" ]]; then
        show_version
        exit 0
    fi
    
    if [[ "$1" == "logs" ]]; then
        local log_type="${2:-all}"
        local lines="${3:-50}"
        show_logs "${log_type}" "${lines}"
        exit 0
    fi
    
    if [[ "$1" == "--debug" ]]; then
        set_debug_mode "true"
        shift
    fi
    
    # If no arguments or "start" is provided, begin the guided workflow
    if [[ $# -eq 0 || "$1" == "start" ]]; then
        start_guided_workflow
        exit 0
    fi
    
    # Handle command dispatch to specific command files
    case "$1" in
        developer)
            shift
            source "$PARENT_DIR/src/commands/developer.sh" "$@"
            exit $?
            ;;
        framework)
            shift
            source "$PARENT_DIR/src/commands/framework.sh" "$@"
            exit $?
            ;;
        clone)
            shift
            source "$PARENT_DIR/src/commands/clone.sh" "$@"
            exit $?
            ;;
        structure)
            shift
            source "$PARENT_DIR/src/commands/structure.sh" "$@"
            exit $?
            ;;
        configure)
            shift
            source "$PARENT_DIR/src/commands/configure.sh" "$@"
            exit $?
            ;;
        dependencies)
            shift
            source "$PARENT_DIR/src/commands/dependencies.sh" "$@"
            exit $?
            ;;
        commands)
            shift
            source "$PARENT_DIR/src/commands/command-list.sh" "$@"
            exit $?
            ;;
        flutter)
            # Handle the flutter command directly
            shift
            # Always delegate to the flutter.sh script for all operations
            if [[ -f "$PARENT_DIR/src/commands/flutter.sh" ]]; then
                source "$PARENT_DIR/src/commands/flutter.sh" "$@"
            else
                log_error "Flutter command script not found."
                exit 1
            fi
            exit $?
            ;;
    esac

    # If any other command is provided, show help
    log_error "Unknown command: $1"
    show_help
    exit 1
}

# Execute main function with all arguments
main "$@" 
# Add this new function to your script
function show_logs() {
    local log_type="$1"  # debug, error, info, step, or all
    local lines="${2:-50}"  # Default to last 50 lines
    
    case "${log_type}" in
        debug)
            log_info "Showing last ${lines} lines of debug log:"
            tail -n "${lines}" "${DEBUG_LOG_FILE}" | less
            ;;
        error)
            log_info "Showing last ${lines} lines of error log:"
            tail -n "${lines}" "${ERROR_LOG_FILE}" | less
            ;;
        info)
            log_info "Showing last ${lines} lines of info log:"
            tail -n "${lines}" "${INFO_LOG_FILE}" | less
            ;;
        step)
            show_step_logs "${lines}"
            ;;
        all)
            log_info "Showing last ${lines} lines of all logs:"
            echo "=== STEP LOG ==="
            tail -n "${lines}" "${STEP_LOG_FILE}"
            echo "=== DEBUG LOG ==="
            tail -n "${lines}" "${DEBUG_LOG_FILE}"
            echo "=== ERROR LOG ==="
            tail -n "${lines}" "${ERROR_LOG_FILE}"
            if [[ -f "${INFO_LOG_FILE}" ]]; then
                echo "=== INFO LOG ==="
                tail -n "${lines}" "${INFO_LOG_FILE}"
            fi
            ;;
        *)
            log_error "Invalid log type: ${log_type}. Use 'debug', 'error', 'info', 'step', or 'all'."
            return 1
            ;;
    esac
}

# Add this function to show step logs specifically
function show_step_logs() {
    local lines="${1:-all}"  # Default to all lines
    
    log_info "Showing step execution logs:"
    if [[ "${lines}" == "all" ]]; then
        cat "${STEP_LOG_FILE}" | less
    else
        tail -n "${lines}" "${STEP_LOG_FILE}" | less
    fi
}
