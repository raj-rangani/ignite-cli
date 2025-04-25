#!/bin/bash
# =============================================
# Clone Command
# Handles Git repository cloning
# =============================================

# Source utility scripts
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
source "${PARENT_DIR}/utils/logger.sh"
source "${PARENT_DIR}/utils/prompts.sh"
source "${PARENT_DIR}/utils/config.sh"
source "${PARENT_DIR}/utils/validators.sh"
source "${PARENT_DIR}/utils/git.sh"

# Display help message for this command
function show_help() {
    log_info "Developer CLI - Git Repository Cloning"
    log_info ""
    log_info "Usage: dev-cli clone [OPTIONS]"
    log_info ""
    log_info "Options:"
    log_info "  --repo=URL           URL of the Git repository to clone"
    log_info "  --branch=BRANCH      Branch to clone (defaults to main/master)"
    log_info "  --dir=PATH           Directory to clone into (defaults to current directory)"
    log_info "  -h, --help           Show this help message"
    log_info ""
    log_info "Examples:"
    log_info "  dev-cli clone"
    log_info "  dev-cli clone --repo=https://github.com/username/repo.git"
    log_info "  dev-cli clone --repo=https://github.com/username/repo.git --branch=develop --dir=~/projects/myapp"
}

# Main function to handle repository cloning
function clone_repository() {
    local repo_url="$1"
    local target_dir="$2"
    local branch="$3"
    
    # Check if git is installed
    if ! check_git_installed; then
        log_error "Git is required for this operation. Please install Git and try again."
        return 1
    fi
    
    # If no repo URL is provided, prompt for it
    if [[ -z "${repo_url}" ]]; then
        repo_url=$(prompt_input "Enter Git repository URL")
        
        # Validate the Git URL
        if ! validate_git_url "${repo_url}"; then
            return 1
        fi
    fi
    
    # If no target directory is provided, prompt for it
    if [[ -z "${target_dir}" ]]; then
        # Extract repo name from URL to suggest as directory name
        local repo_name=$(basename "${repo_url}" .git)
        target_dir=$(prompt_input "Enter target directory" "${repo_name}")
    fi
    
    # Expand the target directory path
    target_dir=$(eval echo "${target_dir}")
    
    # If no branch is provided, prompt for it
    if [[ -z "${branch}" ]]; then
        # Use default branch from config or default to main
        local default_branch=$(get_config "GIT_DEFAULT_BRANCH")
        default_branch=${default_branch:-main}
        
        if prompt_yesno "Do you want to clone a specific branch?" "n"; then
            branch=$(prompt_input "Enter branch name" "${default_branch}")
        else
            branch="${default_branch}"
        fi
    fi
    
    # Clone the repository
    if git_clone "${repo_url}" "${target_dir}" "${branch}"; then
        # Save the project directory to config
        save_project_config "${target_dir}"
        
        # Show success message with next steps
        echo ""
        log_info "Next Steps:"
        log_info "1. Navigate to your project: cd ${target_dir}"
        log_info "2. Configure your project: dev-cli configure"
        log_info "3. View available commands: dev-cli commands"
        
        return 0
    else
        return 1
    fi
}

# Parse command line arguments
function parse_args() {
    local repo_url=""
    local target_dir=""
    local branch=""
    
    # Process command line arguments
    for arg in "$@"; do
        case "${arg}" in
            --repo=*)
                repo_url="${arg#*=}"
                ;;
            --dir=*)
                target_dir="${arg#*=}"
                ;;
            --branch=*)
                branch="${arg#*=}"
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
    
    # Clone repository
    clone_repository "${repo_url}" "${target_dir}" "${branch}"
    return $?
}

# Execute the command
parse_args "$@"
exit $? 