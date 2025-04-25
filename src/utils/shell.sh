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