#!/bin/bash
# =============================================
# Shell Utility Functions
# Handles shell command execution
# =============================================

# Source the logger utility
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/logger.sh"

# Execute a command and show output
function execute_command() {
    local command="$1"
    local error_message="${2:-Command execution failed}"
    
    log_debug "Executing command: ${command}"
    
    eval "${command}"
    local status=$?
    
    if [[ $status -ne 0 ]]; then
        log_error "${error_message} (exit code: ${status})"
        return $status
    fi
    
    return 0
}

# Execute a command silently (no output unless error)
function execute_silent() {
    local command="$1"
    local error_message="${2:-Command execution failed}"
    
    log_debug "Executing command silently: ${command}"
    
    eval "${command}" > /dev/null 2>&1
    local status=$?
    
    if [[ $status -ne 0 ]]; then
        log_error "${error_message} (exit code: ${status})"
        return $status
    fi
    
    return 0
}

# Execute a command with a spinner
function execute_with_spinner() {
    local command="$1"
    local message="${2:-Executing command...}"
    local error_message="${3:-Command execution failed}"
    
    log_debug "Executing command with spinner: ${command}"
    
    # Start the command in the background
    eval "${command}" > /dev/null 2>&1 &
    local pid=$!
    
    # Display spinner while the command is running
    local spin='-\|/'
    local i=0
    
    echo -ne "${message} "
    
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) % 4 ))
        echo -ne "\b${spin:$i:1}"
        sleep 0.1
    done
    
    # Wait for the command to finish
    wait $pid
    local status=$?
    
    echo -ne "\r\033[K"  # Clear the line
    
    if [[ $status -ne 0 ]]; then
        log_error "${error_message} (exit code: ${status})"
        return $status
    fi
    
    log_success "${message} completed successfully"
    return 0
}

# Check if a process is running
function is_process_running() {
    local process_name="$1"
    
    pgrep -f "${process_name}" > /dev/null
    return $?
}

# Kill a process by name
function kill_process() {
    local process_name="$1"
    local signal="${2:-TERM}"
    
    log_info "Stopping process: ${process_name}"
    
    pkill -${signal} -f "${process_name}" > /dev/null 2>&1
    return $?
}

# Find available port
function find_available_port() {
    local start_port="${1:-8000}"
    local max_port="${2:-9000}"
    
    for port in $(seq ${start_port} ${max_port}); do
        if ! lsof -i:${port} > /dev/null 2>&1; then
            echo ${port}
            return 0
        fi
    done
    
    log_error "No available ports found in range ${start_port}-${max_port}"
    return 1
}

# Check if a tool/command is installed
function is_tool_installed() {
    local tool_name="$1"
    
    if command -v "${tool_name}" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Get OS type (linux, darwin, windows)
function get_os_type() {
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    
    case "${os}" in
        linux*)
            echo "linux"
            ;;
        darwin*)
            echo "darwin"
            ;;
        msys*|mingw*|cygwin*)
            echo "windows"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Get CPU architecture
function get_cpu_arch() {
    local arch=$(uname -m)
    
    case "${arch}" in
        x86_64|amd64)
            echo "amd64"
            ;;
        i386|i686)
            echo "386"
            ;;
        armv7*|armv6*|arm)
            echo "arm"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Read directory contents in a cross-platform way (works on macOS, Linux, and Windows)
function read_directory() {
    local target_dir="$1"
    local show_hidden="${2:-false}"
    local os_type=$(get_os_type)
    
    # Ensure the directory exists
    if [[ ! -d "${target_dir}" ]]; then
        log_error "Directory does not exist: ${target_dir}"
        return 1
    fi
    
    log_debug "Reading directory contents: ${target_dir} (OS: ${os_type})"
    
    case "${os_type}" in
        windows)
            # For Windows (Git Bash/MSYS/MinGW environments)
            if [[ "${show_hidden}" == "true" ]]; then
                # Show all files including hidden ones
                dir -a "${target_dir}" 2>/dev/null || ls -la "${target_dir}" 2>/dev/null
            else
                # Regular directory listing
                dir "${target_dir}" 2>/dev/null || ls -l "${target_dir}" 2>/dev/null
            fi
            ;;
        darwin|linux)
            # For macOS and Linux
            if [[ "${show_hidden}" == "true" ]]; then
                ls -la "${target_dir}"
            else
                ls -l "${target_dir}"
            fi
            ;;
        *)
            # Fallback for unknown OS
            log_warning "Unknown OS type: ${os_type}. Using standard ls command."
            if [[ "${show_hidden}" == "true" ]]; then
                ls -la "${target_dir}"
            else
                ls -l "${target_dir}"
            fi
            ;;
    esac
    
    return $?
}

# Get absolute path in a cross-platform way
function get_absolute_path() {
    local path="$1"
    local os_type=$(get_os_type)
    
    log_debug "Getting absolute path for: ${path} (OS: ${os_type})"
    
    case "${os_type}" in
        windows)
            # For Windows environments
            if command -v realpath >/dev/null 2>&1; then
                realpath "${path}" 2>/dev/null || echo "${path}"
            elif command -v cygpath >/dev/null 2>&1; then
                cygpath -a "${path}" 2>/dev/null || echo "${path}"
            else
                # Fallback for Windows without helper tools
                cd $(dirname "${path}") >/dev/null 2>&1 && echo "$(pwd)/$(basename "${path}")" || echo "${path}"
                cd - >/dev/null 2>&1
            fi
            ;;
        darwin|linux)
            # For macOS and Linux
            if command -v realpath >/dev/null 2>&1; then
                realpath "${path}" 2>/dev/null || echo "${path}"
            else
                # Alternative for systems without realpath
                cd $(dirname "${path}") >/dev/null 2>&1 && echo "$(pwd)/$(basename "${path}")" || echo "${path}"
                cd - >/dev/null 2>&1
            fi
            ;;
        *)
            # Fallback for unknown OS
            log_warning "Unknown OS type: ${os_type}. Using basic path resolution."
            cd $(dirname "${path}") >/dev/null 2>&1 && echo "$(pwd)/$(basename "${path}")" || echo "${path}"
            cd - >/dev/null 2>&1
            ;;
    esac
}

# Create directory in a cross-platform way
function create_directory() {
    local dir_path="$1"
    local create_parents="${2:-true}"
    local os_type=$(get_os_type)
    
    log_debug "Creating directory: ${dir_path} (OS: ${os_type})"
    
    # Check if directory already exists
    if [[ -d "${dir_path}" ]]; then
        log_debug "Directory already exists: ${dir_path}"
        return 0
    fi
    
    # Create directory
    if [[ "${create_parents}" == "true" ]]; then
        # Create parent directories if needed
        case "${os_type}" in
            windows)
                # For Windows
                mkdir -p "${dir_path}" 2>/dev/null || mkdir "${dir_path}" 2>/dev/null
                ;;
            *)
                # For Unix-like OS
                mkdir -p "${dir_path}"
                ;;
        esac
    else
        # Create only the specified directory
        mkdir "${dir_path}"
    fi
    
    local status=$?
    if [[ $status -ne 0 ]]; then
        log_error "Failed to create directory: ${dir_path}"
        return $status
    fi
    
    log_debug "Directory created successfully: ${dir_path}"
    return 0
}

# Check if file exists in a cross-platform way
function file_exists() {
    local file_path="$1"
    local os_type=$(get_os_type)
    
    log_debug "Checking if file exists: ${file_path} (OS: ${os_type})"
    
    if [[ -f "${file_path}" ]]; then
        log_debug "File exists: ${file_path}"
        return 0
    else
        log_debug "File does not exist: ${file_path}"
        return 1
    fi
}

# Check if directory exists in a cross-platform way
function directory_exists() {
    local dir_path="$1"
    local os_type=$(get_os_type)
    
    log_debug "Checking if directory exists: ${dir_path} (OS: ${os_type})"
    
    if [[ -d "${dir_path}" ]]; then
        log_debug "Directory exists: ${dir_path}"
        return 0
    else
        log_debug "Directory does not exist: ${dir_path}"
        return 1
    fi
}

# Get parent directory in a cross-platform way
function get_parent_directory() {
    local path="$1"
    local os_type=$(get_os_type)
    
    log_debug "Getting parent directory for: ${path} (OS: ${os_type})"
    
    case "${os_type}" in
        windows)
            # For Windows
            local parent=$(dirname "${path}" 2>/dev/null)
            if [[ $? -eq 0 && -n "${parent}" ]]; then
                echo "${parent}"
                return 0
            else
                # Alternative method for Windows
                echo "${path%\\*}"
                return $?
            fi
            ;;
        *)
            # For Unix-like OS
            dirname "${path}"
            return $?
            ;;
    esac
}

# Get home directory in a cross-platform way
function get_home_directory() {
    local os_type=$(get_os_type)
    
    log_debug "Getting home directory (OS: ${os_type})"
    
    case "${os_type}" in
        windows)
            # For Windows
            if [[ -n "${USERPROFILE}" ]]; then
                echo "${USERPROFILE}"
            elif [[ -n "${HOMEDRIVE}" && -n "${HOMEPATH}" ]]; then
                echo "${HOMEDRIVE}${HOMEPATH}"
            else
                echo "${HOME}"
            fi
            ;;
        *)
            # For Unix-like OS
            echo "${HOME}"
            ;;
    esac
}

# Convert path to platform-specific format
function convert_path_to_platform() {
    local path="$1"
    local os_type=$(get_os_type)
    
    log_debug "Converting path to platform format: ${path} (OS: ${os_type})"
    
    case "${os_type}" in
        windows)
            # Convert to Windows path format
            if command -v cygpath >/dev/null 2>&1; then
                cygpath -w "${path}"
            else
                # Basic conversion - replace forward slashes with backslashes
                echo "${path}" | tr '/' '\\'
            fi
            ;;
        *)
            # For Unix-like OS - replace backslashes with forward slashes
            echo "${path}" | tr '\\' '/'
            ;;
    esac
}

# Run a command as sudo (with password prompt if needed)
function run_as_sudo() {
    local command="$1"
    
    if [[ $(id -u) -eq 0 ]]; then
        # Already running as root
        eval "${command}"
    else
        # Need sudo
        log_info "This operation requires sudo privileges"
        sudo sh -c "${command}"
    fi
    
    return $?
} 