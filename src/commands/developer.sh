#!/bin/bash
# =============================================
# Developer Command
# Handles developer role selection
# =============================================

# Source utility scripts
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
source "${PARENT_DIR}/utils/logger.sh"
source "${PARENT_DIR}/utils/prompts.sh"
source "${PARENT_DIR}/utils/config.sh"
source "${PARENT_DIR}/utils/validators.sh"

# Display help message for this command
function show_help() {
    log_info "Developer CLI - Developer Role Selection"
    log_info ""
    log_info "Usage: dev-cli developer [OPTIONS]"
    log_info ""
    log_info "Options:"
    log_info "  --role=ROLE          Directly select a developer role (mobile, backend, frontend)"
    log_info "  -h, --help           Show this help message"
    log_info ""
    log_info "Examples:"
    log_info "  dev-cli developer"
    log_info "  dev-cli developer --role=frontend"
}

# Main function to handle developer role selection
function select_developer_role() {
    local role="$1"
    
    # If role is provided, validate it
    if [[ -n "${role}" ]]; then
        if ! validate_is_in_list "${role}" "Developer role" "mobile" "backend" "frontend"; then
            return 1
        fi
    else
        # Ask user to select role interactively
        log_section "Select Your Developer Role"
        
        log_info "This will help configure the right tools and setup for your development environment."
        echo ""
        
        # Show role options with descriptions
        echo "Available roles:"
        echo "  1. Mobile Developer - For iOS, Android & Flutter development"
        echo "  2. Backend Developer - For server-side & API development"
        echo "  3. Frontend Developer - For UI & web application development"
        echo ""
        
        # Keep prompting until a valid selection is made
        while true; do
            read -p "Enter role number (1-3): " selection
            
            case "${selection}" in
                1)
                    role="mobile"
                    break
                    ;;
                2)
                    role="backend"
                    break
                    ;;
                3)
                    role="frontend"
                    break
                    ;;
                *)
                    log_error "Invalid selection. Please enter a number between 1 and 3."
                    ;;
            esac
        done
    fi
    
    # Save the selected role to configuration
    set_config "DEVELOPER_ROLE" "${role}"
    
    log_success "Developer role set to: ${role}"
    
    # Show next steps
    echo ""
    log_info "Next Steps:"
    log_info "1. Select a framework: dev-cli framework"
    log_info "2. Clone or create a project: dev-cli clone or dev-cli structure"
    
    return 0
}

# Parse command line arguments
function parse_args() {
    local role=""
    
    # Process command line arguments
    for arg in "$@"; do
        case "${arg}" in
            --role=*)
                role="${arg#*=}"
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
    
    # Select developer role
    select_developer_role "${role}"
    return $?
}

# Execute the command
parse_args "$@"
exit $? 