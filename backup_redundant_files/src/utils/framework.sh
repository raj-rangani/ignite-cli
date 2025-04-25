#!/bin/bash
# =============================================
# Framework Utility Functions
# =============================================

# Function to get available frameworks for a role
function get_frameworks_for_role() {
    local role="$1"
    
    case "${role}" in
        mobile)
            echo "flutter react-native"
            ;;
        backend)
            echo "nodejs laravel django"
            ;;
        frontend)
            echo "react vue angular"
            ;;
        fullstack)
            echo "mern mean laravel-vue"
            ;;
        *)
            echo ""
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
        django)
            echo "Python web framework"
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
        mern)
            echo "MongoDB, Express, React, Node.js stack"
            ;;
        mean)
            echo "MongoDB, Express, Angular, Node.js stack"
            ;;
        laravel-vue)
            echo "Laravel PHP framework with Vue.js frontend"
            ;;
        *)
            echo "No description available"
            ;;
    esac
}

# Function to validate if a framework is available for a role
function is_framework_valid_for_role() {
    local framework="$1"
    local role="$2"
    
    local available_frameworks=($(get_frameworks_for_role "${role}"))
    
    for fw in "${available_frameworks[@]}"; do
        if [[ "${fw}" == "${framework}" ]]; then
            return 0
        fi
    done
    
    return 1
}

# Function to get template directory for a framework
function get_template_dir() {
    local role="$1"
    local framework="$2"
    
    # Get the parent directory of the utils directory
    local parent_dir="$(dirname "$(dirname "${BASH_SOURCE[0]}")")"
    
    echo "${parent_dir}/templates/${role}/${framework}"
}

# Function to check if a template exists for a framework
function does_template_exist() {
    local role="$1"
    local framework="$2"
    
    local template_dir=$(get_template_dir "${role}" "${framework}")
    
    if [[ -d "${template_dir}" ]]; then
        return 0
    else
        return 1
    fi
} 