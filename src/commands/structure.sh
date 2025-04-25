#!/bin/bash
# Structure command - Handles project structure generation

# Source utility scripts
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
source "${PARENT_DIR}/utils/logger.sh"
source "${PARENT_DIR}/utils/prompts.sh"
source "${PARENT_DIR}/utils/config.sh"
source "${PARENT_DIR}/utils/validators.sh"
source "${PARENT_DIR}/utils/shell.sh"
source "${PARENT_DIR}/utils/git.sh"

# Function to clone a Node.js project
function create_nodejs_project() {
    local project_dir="$1"
    local os_type=$(get_os_type)
    
    log_debug "Creating project directory: ${project_dir} (OS: ${os_type})"
    
    # Check if directory already exists
    if directory_exists "${project_dir}"; then
        # Check if directory is empty in a cross-platform way
        if read_directory "${project_dir}" > /dev/null 2>&1; then
            log_info "Directory already exists and is not empty: ${project_dir}"
            
            # If using current directory, just proceed without asking
            if [[ "${project_dir}" == "." || "${project_dir}" == "$(pwd)" ]]; then
                log_info "Using current directory for project structure."
            else
                # Ask if user wants to proceed
                if ! prompt_yesno "Do you want to continue and possibly overwrite files?" "n"; then
                    return 1
                fi
            fi
        fi
    else
        # Create the directory using cross-platform function
        if ! create_directory "${project_dir}"; then
            log_error "Failed to create project directory: ${project_dir}"
            return 1
        fi
    fi
    
    # Move files from temp directory to project directory
    cp -r temp_nodejs/* .
    cp -r temp_nodejs/.* . 2>/dev/null || true
    
    # Cleanup
    rm -rf temp_nodejs
    rm -rf .git
    
    # Update package.json with project name
    if [ -f "package.json" ]; then
        sed -i "s/\"name\": \".*\"/\"name\": \"${project_name}\"/" package.json
    fi
    
    log_success "Node.js project structure created successfully"
    echo "PROJECT_DIRECTORY:${project_dir}"
    return 0
}

# Function to create a Laravel project
function create_laravel_project() {
    local project_dir="$1"
    local project_name="$2"
    
    # Ensure we're in the project directory
    cd "${project_dir}" || return 1
    
    log_info "Creating Laravel project..."
    
    # Check if Composer is installed
    if ! command -v composer &> /dev/null; then
        log_error "Composer is not installed. Please install Composer first."
        return 1
    fi
    
    # Create new Laravel project
    composer create-project laravel/laravel .
    
    if [ $? -ne 0 ]; then
        log_error "Failed to create Laravel project"
        return 1
    fi
    
    log_success "Laravel project structure created successfully"
    echo "PROJECT_DIRECTORY:${project_dir}"
    return 0
}

# Function to generate project structure
function generate_structure() {
    local role="$1"
    local framework="$2"
    local project_name="$3"
    local project_dir="$4"
    
    # Create project directory if it doesn't exist
    if [ ! -d "${project_dir}" ]; then
        mkdir -p "${project_dir}"
    fi
    
    # Generate structure based on framework
    case "${framework}" in
        nodejs)
            create_nodejs_project "${project_dir}" "${project_name}"
            ;;
        laravel)
            create_laravel_project "${project_dir}" "${project_name}"
            ;;
        *)
            log_error "Unsupported framework: ${framework}"
            return 1
            ;;
    esac
    
    return $?
}

# Parse command line arguments
role=""
framework=""
project_name=""
project_dir=""
init_git="false"

while [ $# -gt 0 ]; do
    case "$1" in
        --role=*)
            role="${1#*=}"
            ;;
        --framework=*)
            framework="${1#*=}"
            ;;
        --name=*)
            project_name="${1#*=}"
            ;;
        --dir=*)
            project_dir="${1#*=}"
            ;;
        --git)
            init_git="true"
            ;;
        *)
            # Ignore unknown options
            ;;
    esac
    shift
done

# Execute command if all required parameters are present
if [ -n "${role}" ] && [ -n "${framework}" ] && [ -n "${project_name}" ] && [ -n "${project_dir}" ]; then
    generate_structure "${role}" "${framework}" "${project_name}" "${project_dir}"
    exit $?
else
    log_error "Missing required parameters"
    exit 1
fi