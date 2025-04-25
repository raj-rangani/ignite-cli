#!/bin/bash
# Structure command - Handles project structure generation

# Source utility scripts
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
source "${PARENT_DIR}/utils/logger.sh"
source "${PARENT_DIR}/utils/prompts.sh"
source "${PARENT_DIR}/utils/config.sh"
source "${PARENT_DIR}/utils/validators.sh"
source "${PARENT_DIR}/utils/shell.sh"
source "${PARENT_DIR}/utils/git.sh"

# Function to clone a Node.js project
function create_nodejs_project() {
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
    
    # Move files from temp directory to project directory
    cp -r temp_nodejs/* .
    cp -r temp_nodejs/.* . 2>/dev/null || true
    
    # Cleanup
    rm -rf temp_nodejs
    rm -rf .git
    
    # Update package.json with project name
    if [ -f "package.json" ]; then
        sed -i "s/\"name\": \".*\"/\"name\": \"${project_name}\"/" package.json
    fi
    
    log_success "Node.js project structure created successfully"
    echo "PROJECT_DIRECTORY:${project_dir}"
    return 0
}

# Function to create a Laravel project
function create_laravel_project() {
    local project_dir="$1"
    local project_name="$2"
    
    # Ensure we're in the project directory
    cd "${project_dir}" || return 1
    
    log_info "Creating Laravel project..."
    
    # Check if Composer is installed
    if ! command -v composer &> /dev/null; then
        log_error "Composer is not installed. Please install Composer first."
        log_info "Creating basic Laravel project structure as fallback..."
        create_laravel_fallback "${project_dir}" "${project_name}"
        return 0
    fi
    
    # Create new Laravel project
    composer create-project laravel/laravel .
    
    if [ $? -ne 0 ]; then
        log_error "Failed to create Laravel project with composer"
        log_info "Creating basic Laravel project structure as fallback..."
        create_laravel_fallback "${project_dir}" "${project_name}"
        return 0
    fi
    
    log_success "Laravel project structure created successfully"
    echo "PROJECT_DIRECTORY:${project_dir}"
    return 0
}

# Function to create a basic Laravel project structure as fallback
function create_laravel_fallback() {
    local project_dir="$1"
    local project_name="$2"
    
    log_info "Setting up basic Laravel project structure..."
    
    # Create basic directory structure
    mkdir -p app/Http/Controllers
    mkdir -p app/Models
    mkdir -p app/Providers
    mkdir -p bootstrap/cache
    mkdir -p config
    mkdir -p database/migrations
    mkdir -p database/seeders
    mkdir -p public
    mkdir -p resources/views
    mkdir -p routes
    mkdir -p storage/app/public
    mkdir -p storage/framework/cache
    mkdir -p storage/framework/sessions
    mkdir -p storage/framework/views
    mkdir -p storage/logs
    mkdir -p tests
    
    # Make storage and bootstrap/cache directories writable
    chmod -R 775 storage
    chmod -R 775 bootstrap/cache
    
    # Create basic .env file
    cat > .env << EOF
APP_NAME="${project_name}"
APP_ENV=local
APP_KEY=
APP_DEBUG=true
APP_URL=http://localhost

LOG_CHANNEL=stack
LOG_LEVEL=debug

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=${project_name}
DB_USERNAME=root
DB_PASSWORD=

BROADCAST_DRIVER=log
CACHE_DRIVER=file
QUEUE_CONNECTION=sync
SESSION_DRIVER=file
SESSION_LIFETIME=120

MEMCACHED_HOST=127.0.0.1

REDIS_HOST=127.0.0.1
REDIS_PASSWORD=null
REDIS_PORT=6379

MAIL_MAILER=smtp
MAIL_HOST=mailhog
MAIL_PORT=1025
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_ENCRYPTION=null
MAIL_FROM_ADDRESS=null
MAIL_FROM_NAME="${project_name}"
EOF
    
    # Create .env.example as a copy of .env
    cp .env .env.example
    
    # Create a basic routes file
    cat > routes/web.php << EOF
<?php

use Illuminate\\Support\\Facades\\Route;

/*
|--------------------------------------------------------------------------
| Web Routes
|--------------------------------------------------------------------------
|
| Here is where you can register web routes for your application. These
| routes are loaded by the RouteServiceProvider within a group which
| contains the "web" middleware group. Now create something great!
|
*/

Route::get('/', function () {
    return view('welcome');
});
EOF
    
    # Create a welcome view
    mkdir -p resources/views
    cat > resources/views/welcome.blade.php << EOF
<!DOCTYPE html>
<html>
<head>
    <title>{{ config('app.name') }}</title>
    <style>
        body {
            font-family: 'Arial', sans-serif;
            margin: 0;
            padding: 0;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            background-color: #f3f4f6;
        }
        .container {
            max-width: 800px;
            padding: 2rem;
            background-color: white;
            border-radius: 0.5rem;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
            text-align: center;
        }
        h1 {
            color: #ef3b2d;
        }
        p {
            color: #718096;
            margin-bottom: 1.5rem;
        }
        .links a {
            display: inline-block;
            margin: 0 0.5rem;
            padding: 0.5rem 1rem;
            background-color: #ef3b2d;
            color: white;
            text-decoration: none;
            border-radius: 0.25rem;
            transition: background-color 0.3s;
        }
        .links a:hover {
            background-color: #cc2f25;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Laravel Fallback Project</h1>
        <p>This is a basic Laravel project structure created by the Developer CLI Tool.</p>
        <p>To complete the setup, please run the following commands:</p>
        <pre>composer install
php artisan key:generate</pre>
        <div class="links">
            <a href="https://laravel.com/docs">Documentation</a>
            <a href="https://laracasts.com">Laracasts</a>
            <a href="https://github.com/laravel/laravel">GitHub</a>
        </div>
    </div>
</body>
</html>
EOF
    
    # Create a basic composer.json file
    cat > composer.json << EOF
{
    "name": "laravel/laravel",
    "type": "project",
    "description": "The Laravel Framework.",
    "keywords": ["framework", "laravel"],
    "license": "MIT",
    "require": {
        "php": "^8.0",
        "laravel/framework": "^9.0"
    },
    "require-dev": {
        "fakerphp/faker": "^1.9.1",
        "laravel/sail": "^1.0.1",
        "mockery/mockery": "^1.4.4",
        "phpunit/phpunit": "^9.5.10"
    },
    "autoload": {
        "psr-4": {
            "App\\\\": "app/",
            "Database\\\\Factories\\\\": "database/factories/",
            "Database\\\\Seeders\\\\": "database/seeders/"
        }
    },
    "autoload-dev": {
        "psr-4": {
            "Tests\\\\": "tests/"
        }
    },
    "scripts": {
        "post-autoload-dump": [
            "Illuminate\\\\Foundation\\\\ComposerScripts::postAutoloadDump",
            "@php artisan package:discover --ansi"
        ],
        "post-update-cmd": [
            "@php artisan vendor:publish --tag=laravel-assets --ansi --force"
        ],
        "post-root-package-install": [
            "@php -r \\"file_exists('.env') || copy('.env.example', '.env');\\"" 
        ],
        "post-create-project-cmd": [
            "@php artisan key:generate --ansi"
        ]
    },
    "extra": {
        "laravel": {
            "dont-discover": []
        }
    },
    "config": {
        "optimize-autoloader": true,
        "preferred-install": "dist",
        "sort-packages": true
    },
    "minimum-stability": "dev",
    "prefer-stable": true
}
EOF
    
    # Create a README.md file
    cat > README.md << EOF
# ${project_name}

This is a Laravel project created using the Developer CLI Tool.

## Setup

1. Install Composer dependencies:
\`\`\`bash
composer install
\`\`\`

2. Generate an application key:
\`\`\`bash
php artisan key:generate
\`\`\`

3. Configure your database in the .env file.

4. Run migrations:
\`\`\`bash
php artisan migrate
\`\`\`

5. Start the development server:
\`\`\`bash
php artisan serve
\`\`\`

## Project Structure

This is a standard Laravel project with the following structure:

- app/ - Contains your application's code
- bootstrap/ - Contains files that bootstrap the framework
- config/ - Contains configuration files
- database/ - Contains database migrations and seeders
- public/ - Contains publicly accessible files
- resources/ - Contains views and frontend assets
- routes/ - Contains route definitions
- storage/ - Contains logs, compiled templates, and file uploads
- tests/ - Contains test files

## Additional Resources

- [Laravel Documentation](https://laravel.com/docs)
- [Laracasts](https://laracasts.com)
- [Laravel GitHub Repository](https://github.com/laravel/laravel)
EOF
    
    log_success "Basic Laravel project structure created successfully"
    log_info "To complete setup, run 'composer install' and 'php artisan key:generate'"
    echo "PROJECT_DIRECTORY:${project_dir}"
}

# Function to generate project structure
function generate_structure() {
    local role="$1"
    local framework="$2"
    local project_name="$3"
    local project_dir="$4"
    
    # Create project directory if it doesn't exist
    if [ ! -d "${project_dir}" ]; then
        mkdir -p "${project_dir}"
    fi
    
    # Generate structure based on framework
    case "${framework}" in
        nodejs)
            create_nodejs_project "${project_dir}" "${project_name}"
            ;;
        laravel)
            create_laravel_project "${project_dir}" "${project_name}"
            ;;
        *)
            log_error "Unsupported framework: ${framework}"
            return 1
            ;;
    esac
    
    return $?
}

# Parse command line arguments
role=""
framework=""
project_name=""
project_dir=""
init_git="false"

while [ $# -gt 0 ]; do
    case "$1" in
        --role=*)
            role="${1#*=}"
            ;;
        --framework=*)
            framework="${1#*=}"
            ;;
        --name=*)
            project_name="${1#*=}"
            ;;
        --dir=*)
            project_dir="${1#*=}"
            ;;
        --git)
            init_git="true"
            ;;
        *)
            # Ignore unknown options
            ;;
    esac
    shift
done

# Execute command if all required parameters are present
if [ -n "${role}" ] && [ -n "${framework}" ] && [ -n "${project_name}" ] && [ -n "${project_dir}" ]; then
    generate_structure "${role}" "${framework}" "${project_name}" "${project_dir}"
    exit $?
else
    log_error "Missing required parameters"
    exit 1
fi