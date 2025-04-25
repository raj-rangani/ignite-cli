#!/bin/bash
# =============================================
# Validators Utility Functions
# Input validation functions for CLI
# =============================================

# Source the logger utility
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/logger.sh"

# Validate if a value is not empty
function validate_not_empty() {
    local value="$1"
    local field_name="${2:-value}"
    
    if [[ -z "${value}" ]]; then
        log_error "${field_name} cannot be empty"
        return 1
    fi
    
    return 0
}

# Validate if a file exists
function validate_file_exists() {
    local file_path="$1"
    
    if [[ ! -f "${file_path}" ]]; then
        log_error "File does not exist: ${file_path}"
        return 1
    fi
    
    return 0
}

# Validate if a directory exists
function validate_dir_exists() {
    local dir_path="$1"
    
    if [[ ! -d "${dir_path}" ]]; then
        log_error "Directory does not exist: ${dir_path}"
        return 1
    fi
    
    return 0
}

# Validate if a command exists on the system
function validate_command_exists() {
    local command="$1"
    
    if ! command -v "${command}" &> /dev/null; then
        log_error "Command not found: ${command}"
        return 1
    fi
    
    return 0
}

# Validate if a value is a number
function validate_is_number() {
    local value="$1"
    local field_name="${2:-value}"
    
    if ! [[ "${value}" =~ ^[0-9]+$ ]]; then
        log_error "${field_name} must be a number"
        return 1
    fi
    
    return 0
}

# Validate if a value is a URL
function validate_is_url() {
    local value="$1"
    local field_name="${2:-URL}"
    
    # Simple URL validation regex
    if ! [[ "${value}" =~ ^(http|https|git)://[a-zA-Z0-9][-a-zA-Z0-9]*(\.[a-zA-Z0-9][-a-zA-Z0-9]*)+(/[a-zA-Z0-9\._/~%\-\+&\#\?!=\(\)@]*)?$ ]]; then
        log_error "${field_name} must be a valid URL"
        return 1
    fi
    
    return 0
}

# Validate if a value is a valid email
function validate_is_email() {
    local value="$1"
    local field_name="${2:-email}"
    
    # Simple email validation regex
    if ! [[ "${value}" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        log_error "${field_name} must be a valid email address"
        return 1
    fi
    
    return 0
}

# Validate if a value is one of the allowed options
function validate_is_in_list() {
    local value="$1"
    local field_name="${2:-value}"
    shift 2
    local allowed_values=("$@")
    
    for allowed in "${allowed_values[@]}"; do
        if [[ "${value}" == "${allowed}" ]]; then
            return 0
        fi
    done
    
    log_error "${field_name} must be one of: ${allowed_values[*]}"
    return 1
}

# Validate if a path is writable
function validate_is_writable() {
    local path="$1"
    
    if [[ ! -w "${path}" ]]; then
        log_error "Path is not writable: ${path}"
        return 1
    fi
    
    return 0
}

# Validate if git repository URL is valid
function validate_git_url() {
    local repo_url="$1"
    
    # Check if it's an SSH URL
    if [[ "${repo_url}" =~ ^git@[a-zA-Z0-9.-]+:[a-zA-Z0-9/_.-]+\.git$ ]]; then
        return 0
    fi
    
    # Check if it's an HTTPS URL
    if [[ "${repo_url}" =~ ^https?://[a-zA-Z0-9.-]+/[a-zA-Z0-9/_.-]+\.git$ ]]; then
        return 0
    fi
    
    log_error "Invalid Git repository URL: ${repo_url}"
    log_error "URL should be in format: https://github.com/username/repo.git or git@github.com:username/repo.git"
    return 1
}

# Validate if a port number is valid
function validate_port_number() {
    local port="$1"
    
    if ! [[ "${port}" =~ ^[0-9]+$ ]] || [ "${port}" -lt 1 ] || [ "${port}" -gt 65535 ]; then
        log_error "Invalid port number: ${port}. Port must be between 1 and 65535."
        return 1
    fi
    
    return 0
}

# Validate if string matches a pattern
function validate_pattern() {
    local value="$1"
    local pattern="$2"
    local field_name="${3:-value}"
    local error_message="${4:-must match the required pattern}"
    
    if ! [[ "${value}" =~ ${pattern} ]]; then
        log_error "${field_name} ${error_message}"
        return 1
    fi
    
    return 0
} 