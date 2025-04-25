#!/bin/bash
# =============================================
# Framework Command
# Handles framework selection based on developer role
# =============================================

# Source utility scripts
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
source "${PARENT_DIR}/utils/logger.sh"
source "${PARENT_DIR}/utils/prompts.sh"
source "${PARENT_DIR}/utils/config.sh"
source "${PARENT_DIR}/utils/validators.sh"
source "${PARENT_DIR}/utils/framework.sh"

# Display help message for this command
function show_help() {
    log_info "Developer CLI - Framework Selection"
    log_info ""
    log_info "Usage: dev-cli framework [OPTIONS]"
    log_info ""
    log_info "Options:"
    log_info "  --role=ROLE          Specify developer role (mobile, backend, frontend)"
    log_info "  --framework=NAME     Directly select a framework"
    log_info "  --list               List available frameworks for the specified role"
    log_info "  -h, --help           Show this help message"
    log_info ""
    log_info "Examples:"
    log_info "  dev-cli framework"
    log_info "  dev-cli framework --role=backend"
    log_info "  dev-cli framework --framework=react"
    log_info "  dev-cli framework --list --role=backend"
}

# Function to get available frameworks for a role
function get_frameworks_for_role() {
    local role="$1"
    
    case "${role}" in
        mobile)
            echo "flutter react-native"
            ;;
        backend)
            echo "nodejs laravel"
            ;;
        frontend)
            echo "react vue angular"
            ;;
        *)
            log_error "Unknown role: ${role}"
            return 1
            ;;
    esac
    
    return 0
}

# Function to get description for a framework
function get_framework_description() {
    local framework="$1"
    
    case "${framework}" in
        flutter)
            echo "Cross-platform UI toolkit by Google"
            ;;
        react-native)
            echo "Mobile app framework using React"
            ;;
        nodejs)
            echo "JavaScript runtime for server-side applications"
            ;;
        laravel)
            echo "PHP web application framework"
            ;;
        react)
            echo "JavaScript library for building user interfaces"
            ;;
        vue)
            echo "Progressive JavaScript framework for UIs"
            ;;
        angular)
            echo "Platform for building mobile & desktop web applications"
            ;;
        *)
            echo "No description available"
            ;;
    esac
}

# Function to list available frameworks for a role
function list_frameworks() {
    local role="$1"
    
    # Validate role
    if ! validate_is_in_list "${role}" "Developer role" "mobile" "backend" "frontend" "fullstack"; then
        return 1
    fi
    
    echo $(get_frameworks_for_role "${role}")
    return 0
}

# Main function to handle framework selection
function select_framework() {
    local role="$1"
    local framework="$2"
    
    # If no role is provided, try to get it from config
    if [[ -z "${role}" ]]; then
        role=$(get_config "DEVELOPER_ROLE")
        
        # If still no role, prompt user to select one
        if [[ -z "${role}" ]]; then
            log_warning "Developer role not set. Please select a role first."
            
            # Source the developer command to select a role
            source "${SCRIPT_DIR}/developer.sh"
            
            # Get the selected role from config
            role=$(get_config "DEVELOPER_ROLE")
            
            # Check if role selection was successful
            if [[ -z "${role}" ]]; then
                log_error "Failed to select developer role."
                return 1
            fi
        fi
    fi
    
    # Validate role
    if ! validate_is_in_list "${role}" "Developer role" "mobile" "backend" "frontend" "fullstack"; then
        return 1
    fi
    
    # Get available frameworks for the selected role
    local available_frameworks=($(get_frameworks_for_role "${role}"))
    
    if [[ ${#available_frameworks[@]} -eq 0 ]]; then
        log_error "No available frameworks for ${role} role."
        return 1
    fi
    
    # If framework is provided, validate it
    if [[ -n "${framework}" ]]; then
        if ! validate_is_in_list "${framework}" "Framework" "${available_frameworks[@]}"; then
            log_error "Framework '${framework}' is not available for ${role} role."
            return 1
        fi
    else
        # Ask user to select framework interactively
        log_section "Select Framework for ${role} Development"
        
        log_info "Available frameworks for ${role} development:"
        echo ""
        
        # Show framework options with descriptions
        local i=1
        for fw in "${available_frameworks[@]}"; do
            local description=$(get_framework_description "${fw}")
            echo "  ${i}. ${fw} - ${description}"
            ((i++))
        done
        echo ""
        
        # Keep prompting until a valid selection is made
        while true; do
            read -p "Enter framework number (1-${#available_frameworks[@]}): " selection
            
            if [[ "${selection}" =~ ^[0-9]+$ ]] && [ "${selection}" -ge 1 ] && [ "${selection}" -le "${#available_frameworks[@]}" ]; then
                framework="${available_frameworks[$((selection-1))]}"
                break
            else
                log_error "Invalid selection. Please enter a number between 1 and ${#available_frameworks[@]}."
            fi
        done
    fi
    
    # Save the selected framework to configuration
    set_config "SELECTED_FRAMEWORK" "${framework}"
    
    log_success "Framework set to: ${framework}"
    
    # Show next steps
    echo ""
    log_info "Next Steps:"
    log_info "1. Clone a repository: dev-cli clone"
    log_info "2. Generate project structure: dev-cli structure"
    log_info "3. Configure your framework: dev-cli configure"
    
    return 0
}

# Parse command line arguments
function parse_args() {
    local role=""
    local framework=""
    local list_mode=false
    
    # Process command line arguments
    for arg in "$@"; do
        case "${arg}" in
            --role=*)
                role="${arg#*=}"
                ;;
            --framework=*)
                framework="${arg#*=}"
                ;;
            --list)
                list_mode=true
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
    
    # If in list mode, just output available frameworks for the role
    if [[ "${list_mode}" == true ]]; then
        list_frameworks "${role}"
        exit $?
    fi
    
    # Select framework
    select_framework "${role}" "${framework}"
    return $?
}

# Execute the command
parse_args "$@"
exit $? 