#!/bin/bash
# =============================================
# Git Utility Functions
# Handles Git operations for the CLI
# =============================================

# Source the logger and validators utilities
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/logger.sh"
source "${SCRIPT_DIR}/validators.sh"

# Check if git is installed
function check_git_installed() {
    if ! command -v git &> /dev/null; then
        log_error "Git is not installed. Please install Git before continuing."
        return 1
    fi
    
    return 0
}

# Clone a Git repository
function git_clone() {
    local repo_url="$1"
    local target_dir="${2:-.}"
    local branch="$3"
    
    # Validate inputs
    validate_git_url "${repo_url}" || return 1
    
    # Check if git is installed
    check_git_installed || return 1
    
    # Create target directory if it doesn't exist
    if [[ ! -d "${target_dir}" ]]; then
        mkdir -p "${target_dir}"
    fi
    
    # Clone the repository
    log_info "Cloning repository: ${repo_url} to ${target_dir}"
    
    if [[ -n "${branch}" ]]; then
        # Clone specific branch
        git clone --branch "${branch}" "${repo_url}" "${target_dir}"
    else
        # Clone default branch
        git clone "${repo_url}" "${target_dir}"
    fi
    
    if [[ $? -ne 0 ]]; then
        log_error "Failed to clone repository"
        return 1
    fi
    
    log_success "Repository cloned successfully"
    return 0
}

# Initialize a Git repository
function git_init() {
    local target_dir="${1:-.}"
    
    # Check if git is installed
    check_git_installed || return 1
    
    # Create target directory if it doesn't exist
    if [[ ! -d "${target_dir}" ]]; then
        mkdir -p "${target_dir}"
    fi
    
    # Change to target directory
    cd "${target_dir}" || return 1
    
    # Initialize the repository
    log_info "Initializing Git repository in ${target_dir}"
    git init
    
    if [[ $? -ne 0 ]]; then
        log_error "Failed to initialize repository"
        return 1
    fi
    
    log_success "Git repository initialized successfully"
    return 0
}

# Add files to Git
function git_add() {
    local target_dir="${1:-.}"
    local files="${2:-.}"
    
    # Check if git is installed
    check_git_installed || return 1
    
    # Change to target directory
    cd "${target_dir}" || return 1
    
    # Add files to Git
    log_info "Adding files to Git: ${files}"
    git add ${files}
    
    if [[ $? -ne 0 ]]; then
        log_error "Failed to add files to Git"
        return 1
    fi
    
    log_success "Files added to Git successfully"
    return 0
}

# Commit changes to Git
function git_commit() {
    local target_dir="${1:-.}"
    local message="$2"
    
    # Check if git is installed
    check_git_installed || return 1
    
    # Validate commit message
    if [[ -z "${message}" ]]; then
        message="Initial commit"
    fi
    
    # Change to target directory
    cd "${target_dir}" || return 1
    
    # Commit changes
    log_info "Committing changes: ${message}"
    git commit -m "${message}"
    
    if [[ $? -ne 0 ]]; then
        log_error "Failed to commit changes"
        return 1
    fi
    
    log_success "Changes committed successfully"
    return 0
}

# Set up Git user information
function git_setup_user() {
    local name="$1"
    local email="$2"
    
    # Check if git is installed
    check_git_installed || return 1
    
    # Validate inputs
    validate_not_empty "${name}" "Git username" || return 1
    validate_is_email "${email}" || return 1
    
    # Set user name and email
    log_info "Setting up Git user: ${name} <${email}>"
    git config --global user.name "${name}"
    git config --global user.email "${email}"
    
    if [[ $? -ne 0 ]]; then
        log_error "Failed to set up Git user"
        return 1
    fi
    
    log_success "Git user set up successfully"
    return 0
}

# Check if we're inside a Git repository
function git_is_repo() {
    local target_dir="${1:-.}"
    
    # Check if git is installed
    check_git_installed || return 1
    
    # Change to target directory
    cd "${target_dir}" 2>/dev/null || return 1
    
    # Check if this is a Git repository
    if git rev-parse --is-inside-work-tree &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Get the current branch name
function git_current_branch() {
    local target_dir="${1:-.}"
    
    # Check if git is installed
    check_git_installed || return 1
    
    # Change to target directory
    cd "${target_dir}" 2>/dev/null || return 1
    
    # Check if this is a Git repository
    if ! git_is_repo "${target_dir}"; then
        log_error "Not a Git repository: ${target_dir}"
        return 1
    fi
    
    # Get the current branch name
    git rev-parse --abbrev-ref HEAD
    return $?
}

# Get available remote branches
function git_list_branches() {
    local target_dir="${1:-.}"
    
    # Check if git is installed
    check_git_installed || return 1
    
    # Change to target directory
    cd "${target_dir}" 2>/dev/null || return 1
    
    # Check if this is a Git repository
    if ! git_is_repo "${target_dir}"; then
        log_error "Not a Git repository: ${target_dir}"
        return 1
    fi
    
    # List branches
    git branch -a | sed 's/^[ *]*//' | sort
    return $?
} 