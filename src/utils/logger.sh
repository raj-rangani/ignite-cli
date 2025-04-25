#!/bin/bash
# =============================================
# Logger Utility Functions
# Provides formatted output functions for CLI
# =============================================

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# Log an info message (blue text)
function log_info() {
    echo -e "${BLUE}[INFO]${RESET} $1"
}

# Log a success message (green text)
function log_success() {
    echo -e "${GREEN}[SUCCESS]${RESET} $1"
}

# Log a warning message (yellow text)
function log_warning() {
    echo -e "${YELLOW}[WARNING]${RESET} $1"
}

# Log an error message (red text)
function log_error() {
    echo -e "${RED}[ERROR]${RESET} $1" >&2
}

# Log a debug message (only when DEBUG is set)
function log_debug() {
    if [[ "${DEBUG}" == "true" ]]; then
        echo -e "${MAGENTA}[DEBUG]${RESET} $1"
    fi
}

# Log a section header (cyan bold text)
function log_section() {
    echo -e "\n${CYAN}${BOLD}$1${RESET}\n"
}

# Display a progress indicator
function show_spinner() {
    local message=$1
    local pid=$2
    local spin='-\|/'
    local i=0
    
    echo -ne "${BLUE}[WORKING]${RESET} $message "
    
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) % 4 ))
        echo -ne "\b${spin:$i:1}"
        sleep 0.1
    done
    
    echo -ne "\b"
}

# Display a task with status (for use with task lists)
function log_task() {
    local task="$1"
    local status="$2"
    local max_length=50
    local dots=""
    
    # Calculate how many dots to add
    local task_length=${#task}
    local num_dots=$(( max_length - task_length ))
    
    # Create the dots string
    for ((i=0; i<num_dots; i++)); do
        dots="${dots}."
    done
    
    # Output with appropriate color based on status
    if [[ "$status" == "OK" ]]; then
        echo -e "${task}${dots}${GREEN}${status}${RESET}"
    elif [[ "$status" == "FAILED" ]]; then
        echo -e "${task}${dots}${RED}${status}${RESET}"
    elif [[ "$status" == "SKIPPED" ]]; then
        echo -e "${task}${dots}${YELLOW}${status}${RESET}"
    else
        echo -e "${task}${dots}${status}"
    fi
}

# Ask for user confirmation (Y/n)
function confirm() {
    local message="${1:-Are you sure you want to continue?}"
    local default="${2:-y}"
    
    if [[ "$default" == "y" ]]; then
        prompt="Y/n"
    else
        prompt="y/N"
    fi
    
    read -p "$message [$prompt]: " response
    response=${response:-$default}
    
    if [[ ${response,,} =~ ^(yes|y)$ ]]; then
        return 0
    else
        return 1
    fi
} 