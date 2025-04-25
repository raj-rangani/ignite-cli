#!/bin/bash
# =============================================
# Structure Command
# Handles project structure generation
# =============================================

# Source utility scripts
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
source "${PARENT_DIR}/utils/logger.sh"
source "${PARENT_DIR}/utils/prompts.sh"
source "${PARENT_DIR}/utils/config.sh"
source "${PARENT_DIR}/utils/validators.sh"
source "${PARENT_DIR}/utils/shell.sh"
source "${PARENT_DIR}/utils/git.sh"
source "${PARENT_DIR}/utils/framework.sh"

# Display help message for this command
function show_help() {
    log_info "Developer CLI - Project Structure Generation"
    log_info ""
    log_info "Usage: dev-cli structure [OPTIONS]"
    log_info ""
    log_info "Options:"
    log_info "  --role=ROLE          Specify developer role (mobile, backend, frontend)"
    log_info "  --framework=NAME     Specify the framework to use"
    log_info "  --name=NAME          Project name (defaults to 'my-app')"
    log_info "  --dir=PATH           Directory to create project in (defaults to current directory)"
    log_info "  --git                Initialize Git repository"
    log_info "  -h, --help           Show this help message"
    log_info ""
    log_info "Examples:"
    log_info "  dev-cli structure"
    log_info "  dev-cli structure --framework=react --name=my-react-app"
    log_info "  dev-cli structure --role=backend --framework=nodejs --name=api-server --git"
}

# Function to get template directory for a framework
function get_template_dir() {
    local role="$1"
    local framework="$2"
    
    echo "${PARENT_DIR}/templates/${role}/${framework}"
}

# Function to create a project directory
function create_project_dir() {
    local project_dir="$1"
    local os_type=$(get_os_type)
    
    log_debug "Creating project directory: ${project_dir} (OS: ${os_type})"
    
    # Check if directory already exists
    if directory_exists "${project_dir}"; then
        # Check if directory is empty in a cross-platform way
        if read_directory "${project_dir}" > /dev/null 2>&1; then
            log_info "Directory already exists and is not empty: ${project_dir}"
            
            # If using current directory, just proceed without asking
            if [[ "${project_dir}" == "." || "${project_dir}" == "$(pwd)" ]]; then
                log_info "Using current directory for project structure."
            else
                # Ask if user wants to proceed
                if ! prompt_yesno "Do you want to continue and possibly overwrite files?" "n"; then
                    return 1
                fi
            fi
        fi
    else
        # Create the directory using cross-platform function
        if ! create_directory "${project_dir}"; then
            log_error "Failed to create project directory: ${project_dir}"
            return 1
        fi
    fi
    
    log_success "Project directory ready: ${project_dir}"
    # Echo project directory for capture by parent script
    echo "PROJECT_DIRECTORY:${project_dir}"
    return 0
}

# Function to copy template files to project directory
function copy_template_files() {
    local template_dir="$1"
    local project_dir="$2"
    local project_name="$3"
    
    # Check if template directory exists
    if [[ ! -d "${template_dir}" ]]; then
        log_error "Template directory not found: ${template_dir}"
        log_error "This framework template may not be implemented yet."
        return 1
    fi
    
    # Copy template files to project directory
    log_info "Copying template files to project directory..."
    
    # Check if the target directory is already a Git repository
    local is_git_repo=false
    if [[ -d "${project_dir}/.git" ]]; then
        is_git_repo=true
        log_info "Target directory is already a Git repository."
    fi
    
    # Use rsync if available, otherwise fallback to cp
    if command -v rsync &> /dev/null; then
        rsync -a --exclude '.git' "${template_dir}/" "${project_dir}/"
    else
        # Exclude .git directory if it exists in template
        if [[ -d "${template_dir}/.git" ]]; then
            find "${template_dir}" -mindepth 1 -maxdepth 1 -not -name ".git" -exec cp -r {} "${project_dir}/" \;
        else
            cp -r "${template_dir}/"* "${project_dir}/" 2>/dev/null || true
        fi
    fi
    
    if [[ $? -ne 0 ]]; then
        log_error "Failed to copy template files"
        return 1
    fi
    
    # Replace template placeholders with actual project name
    log_info "Customizing project files..."
    
    # Find files that might contain template placeholders
    find "${project_dir}" -type f -not -path "*/node_modules/*" -not -path "*/vendor/*" -not -path "*/.git/*" | while read file; do
        # Skip binary files
        if file "$file" | grep -q "text"; then
            # Replace placeholders
            sed -i "s/{{PROJECT_NAME}}/${project_name}/g" "$file" 2>/dev/null || true
            sed -i "s/{{project_name}}/${project_name,,}/g" "$file" 2>/dev/null || true
            sed -i "s/{{CURRENT_YEAR}}/$(date +%Y)/g" "$file" 2>/dev/null || true
            sed -i "s/{{CURRENT_DATE}}/$(date +%Y-%m-%d)/g" "$file" 2>/dev/null || true
        fi
    done
    
    log_success "Project structure created successfully"
    return 0
}

# Function to initialize git repository
function init_git_repository() {
    local project_dir="$1"
    
    # Check if git is installed
    if ! check_git_installed; then
        log_warning "Git is not installed. Skipping repository initialization."
        return 0
    fi
    
    # Initialize git repository
    log_info "Initializing Git repository..."
    
    # Change to project directory
    cd "${project_dir}" || return 1
    
    # Initialize git
    if ! git_init "."; then
        log_error "Failed to initialize Git repository"
        return 1
    fi
    
    # Create .gitignore if it doesn't exist
    if [[ ! -f ".gitignore" ]]; then
        log_info "Creating .gitignore file..."
        
        # Add common entries to gitignore based on framework
        cat > ".gitignore" << EOF
# System files
.DS_Store
Thumbs.db

# Editor directories and files
.idea/
.vscode/
*.suo
*.ntvs*
*.njsproj
*.sln
*.sw?

# Logs
logs
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Dependencies
node_modules/
vendor/
bower_components/

# Build output
dist/
build/
out/
.next/
.nuxt/
public/dist/

# Environment files
.env
.env.local
.env.development.local
.env.test.local
.env.production.local
EOF
    fi
    
    # Add files to git
    git_add "." || return 1
    
    # Create initial commit
    git_commit "." "Initial commit from dev-cli" || return 1
    
    log_success "Git repository initialized with initial commit"
    return 0
}

# Main function to handle project structure generation
function generate_structure() {
    local role="$1"
    local framework="$2"
    local project_name="$3"
    local project_dir="$4"
    local init_git="$5"
    
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
    
    # If no framework is provided, try to get it from config
    if [[ -z "${framework}" ]]; then
        framework=$(get_config "SELECTED_FRAMEWORK")
        
        # If still no framework, prompt user to select one
        if [[ -z "${framework}" ]]; then
            log_warning "Framework not set. Please select a framework first."
            
            # Source the framework command to select a framework
            source "${SCRIPT_DIR}/framework.sh" "--role=${role}"
            
            # Get the selected framework from config
            framework=$(get_config "SELECTED_FRAMEWORK")
            
            # Check if framework selection was successful
            if [[ -z "${framework}" ]]; then
                log_error "Failed to select framework."
                return 1
            fi
        fi
    fi
    
    # Get available frameworks for the selected role
    local available_frameworks=($(get_frameworks_for_role "${role}"))
    
    # Validate framework
    if ! is_framework_valid_for_role "${framework}" "${role}"; then
        log_error "Framework '${framework}' is not available for ${role} role."
        log_info "Available frameworks: ${available_frameworks[*]}"
        return 1
    fi
    
    # If no project name is provided, prompt for it
    if [[ -z "${project_name}" ]]; then
        project_name=$(prompt_input "Enter project name" "my-${framework}-app")
    fi
    
    # Validate project name
    if ! validate_not_empty "${project_name}" "Project name"; then
        return 1
    fi
    
    # If no project directory is provided, use current directory + project name
    if [[ -z "${project_dir}" ]]; then
        project_dir="$(pwd)/${project_name}"
    elif [[ "${project_dir}" == "." ]]; then
        # If directory is specified as current directory, use it directly
        project_dir="$(pwd)"
    fi
    
    # Expand the project directory path
    project_dir=$(eval echo "${project_dir}")
    
    # Check if we're creating a nested directory with the same name as the parent
    parent_dir=$(dirname "${project_dir}")
    base_name=$(basename "${project_dir}")
    parent_base=$(basename "${parent_dir}")
    
    # If we would create a directory with the same name as its parent
    # and we're not explicitly setting the directory, use the parent instead
    if [[ "${base_name}" == "${parent_base}" && "${project_dir}" != "$(pwd)" && "${project_dir}" != "." ]]; then
        log_warning "Avoiding nested directory with the same name: ${base_name}"
        log_info "Using parent directory: ${parent_dir}"
        project_dir="${parent_dir}"
    fi
    
    # Create project directory
    if ! create_project_dir "${project_dir}"; then
        return 1
    fi
    
    # Get template directory
    local template_dir=$(get_template_dir "${role}" "${framework}")
    
    # Create a basic structure if template doesn't exist
    if [[ ! -d "${template_dir}" ]]; then
        log_warning "No template found for ${framework} framework. Creating basic structure."
        
        # Create basic directories based on framework
        mkdir -p "${project_dir}/src"
        mkdir -p "${project_dir}/tests"
        mkdir -p "${project_dir}/docs"
        
        case "${framework}" in
            nodejs)
                # Create package.json
                cat > "${project_dir}/package.json" << EOF
{
  "name": "${project_name}",
  "version": "1.0.0",
  "description": "A Node.js project",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "dev": "nodemon src/index.js",
    "test": "jest"
  },
  "keywords": [],
  "author": "",
  "license": "ISC",
  "dependencies": {
    "express": "^4.17.1"
  },
  "devDependencies": {
    "nodemon": "^2.0.7",
    "jest": "^27.0.0"
  }
}
EOF
                
                # Create basic index.js
                mkdir -p "${project_dir}/src/routes"
                mkdir -p "${project_dir}/src/controllers"
                mkdir -p "${project_dir}/src/models"
                
                cat > "${project_dir}/src/index.js" << EOF
const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

app.use(express.json());

app.get('/', (req, res) => {
  res.send('Hello World from ${project_name}!');
});

app.listen(port, () => {
  console.log(\`Server running on port \${port}\`);
});
EOF
                
                # Create README.md
                cat > "${project_dir}/README.md" << EOF
# ${project_name}

A Node.js API project.

## Setup

\`\`\`bash
npm install
\`\`\`

## Development

\`\`\`bash
npm run dev
\`\`\`

## Production

\`\`\`bash
npm start
\`\`\`

## Testing

\`\`\`bash
npm test
\`\`\`
EOF

                # Create .env.example file
                cat > "${project_dir}/.env.example" << EOF
# Server configuration
PORT=3000
NODE_ENV=development
API_PREFIX=/api/v1
LOG_LEVEL=info

# Database configuration
DB_HOST=localhost
DB_PORT=27017
DB_NAME=${project_name}_db
DB_USER=
DB_PASSWORD=

# For MongoDB users
# MONGODB_URI=mongodb://localhost:27017/${project_name}_db
EOF
                ;;
            *)
                # Create a generic README.md for other frameworks
                cat > "${project_dir}/README.md" << EOF
# ${project_name}

A ${framework} project.

## Setup

Follow the standard setup process for ${framework} applications.

## Development

Start the development server according to ${framework} conventions.

## Production

Build and deploy according to ${framework} best practices.
EOF
                
                # Create basic env template for Django
                if [[ "${framework}" == "django" ]]; then
                    cat > "${project_dir}/.env.example" << EOF
# Django configuration
DEBUG=True
SECRET_KEY=your_secret_key_here
ALLOWED_HOSTS=localhost,127.0.0.1

# Database configuration
DATABASE_URL=postgres://user:password@localhost:5432/${project_name}_db
EOF
                fi
                
                # Create basic env template for Laravel
                if [[ "${framework}" == "laravel" ]]; then
                    cat > "${project_dir}/.env.example" << EOF
APP_NAME=${project_name}
APP_ENV=local
APP_KEY=
APP_DEBUG=true
APP_URL=http://localhost

DB_CONNECTION=mysql
DB_HOST=localhost
DB_PORT=3306
DB_DATABASE=${project_name}_db
DB_USERNAME=root
DB_PASSWORD=
EOF
                fi
                ;;
        esac
        
        log_success "Basic project structure created"
    else
        # Copy template files to project directory
        if ! copy_template_files "${template_dir}" "${project_dir}" "${project_name}"; then
            return 1
        fi
    fi
    
    # Initialize git repository if requested
    if [[ "${init_git}" == "true" ]]; then
        if ! init_git_repository "${project_dir}"; then
            log_warning "Failed to initialize Git repository. Project structure was created successfully."
        fi
    fi
    
    # Save project configuration
    set_config "PROJECT_NAME" "${project_name}"
    set_config "PROJECT_DIR" "${project_dir}"
    
    # Show success message with next steps
    echo ""
    log_info "Next Steps:"
    log_info "1. Navigate to your project: cd ${project_dir}"
    log_info "2. Install dependencies: dev-cli dependencies"
    log_info "3. Configure your project: dev-cli configure"
    log_info "4. View available commands: dev-cli commands"
    
    return 0
}

# Parse command line arguments
function parse_args() {
    local role=""
    local framework=""
    local project_name=""
    local project_dir=""
    local init_git="false"
    
    # Process command line arguments
    for arg in "$@"; do
        case "${arg}" in
            --role=*)
                role="${arg#*=}"
                ;;
            --framework=*)
                framework="${arg#*=}"
                ;;
            --name=*)
                project_name="${arg#*=}"
                ;;
            --dir=*)
                project_dir="${arg#*=}"
                ;;
            --git)
                init_git="true"
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
    
    # Generate project structure
    generate_structure "${role}" "${framework}" "${project_name}" "${project_dir}" "${init_git}"
    return $?
}

# Execute the command
parse_args "$@"
exit $? 