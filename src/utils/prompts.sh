#!/bin/bash
# =============================================
# Prompts Utility Functions
# Handles interactive user prompts
# =============================================

# Source the logger utility
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/logger.sh"

# Simple text input prompt
function prompt_input() {
    local message="$1"
    local default="$2"
    local value=""
    
    if [[ -n "${default}" ]]; then
        read -p "${message} [${default}]: " value
        value=${value:-$default}
    else
        read -p "${message}: " value
    fi
    
    echo "${value}"
}

# Password input (hidden input)
function prompt_password() {
    local message="$1"
    local value=""
    
    read -s -p "${message}: " value
    echo "" # Add a newline after the hidden input
    
    echo "${value}"
}

# Selection from a list of options (with enumeration)
function prompt_select() {
    local message="$1"
    local options=("${@:2}")
    local selected=""
    
    echo "${message}"
    
    # Display options with numbers
    for i in "${!options[@]}"; do
        echo "  $((i+1)). ${options[$i]}"
    done
    
    # Keep prompting until a valid selection is made
    while true; do
        read -p "Enter number (1-${#options[@]}): " selection
        
        # Check if input is a number and within range
        if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#options[@]}" ]; then
            selected="${options[$((selection-1))]}"
            break
        else
            log_error "Invalid selection. Please enter a number between 1 and ${#options[@]}."
        fi
    done
    
    echo "${selected}"
}

# Multi-selection from a list of options
function prompt_multiselect() {
    local message="$1"
    local options=("${@:2}")
    local selections=()
    
    echo "${message}"
    echo "Enter numbers separated by spaces (e.g., 1 3 5) or 'all' for all options"
    
    # Display options with numbers
    for i in "${!options[@]}"; do
        echo "  $((i+1)). ${options[$i]}"
    done
    
    # Keep prompting until a valid selection is made
    while true; do
        read -p "Enter selection: " input
        
        # If 'all' is selected, include all options
        if [[ "${input}" == "all" ]]; then
            selections=("${options[@]}")
            break
        fi
        
        # Split the input by spaces
        local nums=($input)
        local valid=true
        
        # Check if each number is valid
        for num in "${nums[@]}"; do
            if ! [[ "$num" =~ ^[0-9]+$ ]] || [ "$num" -lt 1 ] || [ "$num" -gt "${#options[@]}" ]; then
                log_error "Invalid selection: $num. Please enter numbers between 1 and ${#options[@]}."
                valid=false
                break
            fi
            
            # Add the selected option to the result
            selections+=("${options[$((num-1))]}")
        done
        
        # If all selections were valid, break out of the loop
        if $valid; then
            break
        fi
    done
    
    # Return the selections as a space-separated string
    echo "${selections[*]}"
}

# Yes/No prompt (returns 0 for Yes, 1 for No)
function prompt_yesno() {
    local message="$1"
    local default="${2:-y}"
    
    if [[ "$default" == "y" ]]; then
        prompt="Y/n"
    else
        prompt="y/N"
    fi
    
    while true; do
        read -p "$message [$prompt]: " response
        response=${response:-$default}
        response=$(echo "$response" | tr '[:upper:]' '[:lower:]')
        
        if [[ "${response}" =~ ^(yes|y)$ ]]; then
            return 0
        elif [[ "${response}" =~ ^(no|n)$ ]]; then
            return 1
        else
            log_error "Invalid response. Please enter y/n."
        fi
    done
}

# Prompt for a path with validation
function prompt_path() {
    local message="$1"
    local default="$2"
    local path=""
    
    while true; do
        if [[ -n "${default}" ]]; then
            read -p "${message} [${default}]: " path
            path=${path:-$default}
        else
            read -p "${message}: " path
        fi
        
        # Expand the path
        path=$(eval echo "${path}")
        
        # Check if path exists (if desired)
        if [[ "$3" == "validate" && ! -e "${path}" ]]; then
            log_error "Path does not exist: ${path}"
        else
            break
        fi
    done
    
    echo "${path}"
}

# Display a spinner while waiting for a command to complete
function prompt_with_spinner() {
    local message="$1"
    local command="$2"
    
    # Run the command in the background
    eval "${command}" &
    local pid=$!
    
    # Display spinner
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
    
    return $status
} 