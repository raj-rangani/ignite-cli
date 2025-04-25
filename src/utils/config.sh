#!/bin/bash
# =============================================
# Configuration Utility Functions
# Manages CLI configuration settings
# =============================================

# Default configuration file path
CONFIG_DIR="${HOME}/.dev-cli"
CONFIG_FILE="${CONFIG_DIR}/config"

# Create config directory if it doesn't exist
function init_config_dir() {
    if [[ ! -d "${CONFIG_DIR}" ]]; then
        mkdir -p "${CONFIG_DIR}" 
        if [[ $? -ne 0 ]]; then
            echo "Failed to create config directory: ${CONFIG_DIR}" >&2
            return 1
        fi
    fi
    
    # Create config file if it doesn't exist
    if [[ ! -f "${CONFIG_FILE}" ]]; then
        touch "${CONFIG_FILE}"
        if [[ $? -ne 0 ]]; then
            echo "Failed to create config file: ${CONFIG_FILE}" >&2
            return 1
        fi
        
        # Add default configuration settings
        echo "# Dev CLI Configuration" > "${CONFIG_FILE}"
        echo "DEVELOPER_ROLE=" >> "${CONFIG_FILE}"
        echo "SELECTED_FRAMEWORK=" >> "${CONFIG_FILE}"
        echo "LAST_PROJECT_DIR=" >> "${CONFIG_FILE}"
        echo "GIT_DEFAULT_BRANCH=main" >> "${CONFIG_FILE}"
    fi
    
    return 0
}

# Get a configuration value
function get_config() {
    local key="$1"
    
    # Make sure config dir and file exist
    init_config_dir
    
    # Read the value from config file
    local value=$(grep "^${key}=" "${CONFIG_FILE}" | cut -d= -f2)
    echo "${value}"
}

# Set a configuration value
function set_config() {
    local key="$1"
    local value="$2"
    
    # Make sure config dir and file exist
    init_config_dir
    
    # Check if the key already exists
    if grep -q "^${key}=" "${CONFIG_FILE}"; then
        # Update existing key
        sed -i "s|^${key}=.*|${key}=${value}|" "${CONFIG_FILE}"
    else
        # Add new key
        echo "${key}=${value}" >> "${CONFIG_FILE}"
    fi
    
    return $?
}

# List all configuration settings
function list_config() {
    # Make sure config dir and file exist
    init_config_dir
    
    # Print config file contents (excluding comments)
    grep -v "^#" "${CONFIG_FILE}" | sort
}

# Reset configuration to defaults
function reset_config() {
    # Make sure config dir exists
    if [[ ! -d "${CONFIG_DIR}" ]]; then
        mkdir -p "${CONFIG_DIR}"
    fi
    
    # Create default config file
    echo "# Dev CLI Configuration" > "${CONFIG_FILE}"
    echo "DEVELOPER_ROLE=" >> "${CONFIG_FILE}"
    echo "SELECTED_FRAMEWORK=" >> "${CONFIG_FILE}"
    echo "LAST_PROJECT_DIR=" >> "${CONFIG_FILE}"
    echo "GIT_DEFAULT_BRANCH=main" >> "${CONFIG_FILE}"
    
    return $?
}

# Save the current project settings
function save_project_config() {
    local project_dir="$1"
    local framework="$2"
    local role="$3"
    
    # Save project-specific settings
    set_config "LAST_PROJECT_DIR" "${project_dir}"
    
    if [[ -n "${framework}" ]]; then
        set_config "SELECTED_FRAMEWORK" "${framework}"
    fi
    
    if [[ -n "${role}" ]]; then
        set_config "DEVELOPER_ROLE" "${role}"
    fi
}

# Load project-specific configuration
function load_project_config() {
    local project_dir="$1"
    local project_config="${project_dir}/.dev-cli-config"
    
    if [[ -f "${project_config}" ]]; then
        # Source the project-specific config
        source "${project_config}"
        return 0
    fi
    
    return 1
}

# Create project-specific configuration
function create_project_config() {
    local project_dir="$1"
    local framework="$2"
    local role="$3"
    
    local project_config="${project_dir}/.dev-cli-config"
    
    echo "# Dev CLI Project Configuration" > "${project_config}"
    echo "PROJECT_FRAMEWORK=${framework}" >> "${project_config}"
    echo "DEVELOPER_ROLE=${role}" >> "${project_config}"
    echo "CREATED_DATE=$(date +'%Y-%m-%d %H:%M:%S')" >> "${project_config}"
    
    return $?
} 