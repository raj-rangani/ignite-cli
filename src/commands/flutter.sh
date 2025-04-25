#!/bin/bash

# =============================================
# Flutter Commands Script
# =============================================

# Get script directory and parent directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Source utility functions
source "$PARENT_DIR/src/utils/logger.sh"
source "$PARENT_DIR/src/utils/validators.sh"
source "$PARENT_DIR/src/utils/config.sh"
source "$PARENT_DIR/src/utils/prompts.sh"

# Main function to handle Flutter operations
function handle_flutter_operations() {
    local command="$1"
    
    case "${command}" in
        create)
            create_flutter_project
            ;;
        flavors)
            setup_flutter_flavors
            ;;
        cicd)
            setup_flutter_cicd
            ;;
        checklist)
            show_cicd_checklist
            ;;
        *)
            if [[ -z "${command}" ]]; then
                create_flutter_project  # Default action if no command provided
            else
                log_error "Unknown Flutter command: ${command}"
                show_flutter_help
                exit 1
            fi
            ;;
    esac
}

# Function to create a new Flutter project
function create_flutter_project() {
    local project_name=""
    local org_id=""
    
    # Check if Flutter is installed
    if ! command -v flutter &> /dev/null; then
        log_error "Flutter SDK not found. Please install Flutter first."
        log_info "Visit https://flutter.dev/docs/get-started/install for installation instructions."
        return 1
    fi
    
    # First check if we have previously saved values
    saved_project_name=$(get_config "FLUTTER_PROJECT_NAME")
    saved_org_id=$(get_config "FLUTTER_ORG_ID")
    
    if [[ -n "${saved_project_name}" && -n "${saved_org_id}" ]]; then
        log_info "Found previously configured Flutter project details:"
        log_info "Project name: ${saved_project_name}"
        log_info "Organization ID: ${saved_org_id}"
        
        read -p "Would you like to use these values? (yes/no): " use_saved
        if [[ "${use_saved}" == "yes" || "${use_saved}" == "y" ]]; then
            project_name="${saved_project_name}"
            org_id="${saved_org_id}"
        else
            # Clear saved values if not using them
            set_config "FLUTTER_PROJECT_NAME" ""
            set_config "FLUTTER_ORG_ID" ""
        fi
    fi
    
    # If we don't have values from saved config, prompt for them
    if [[ -z "${project_name}" || -z "${org_id}" ]]; then
        # Ask for project name with validation
        log_section "Create Flutter Project"
        log_info "Please provide the details for your new Flutter project."
        echo ""
        
        # Prompt for project name with validation
        while true; do
            read -p "Enter project name (lowercase with underscores, e.g., my_app): " project_name
            
            # Validate project name (Flutter requires lowercase with underscores)
            if [[ "${project_name}" =~ ^[a-z][a-z0-9_]*$ ]]; then
                break
            else
                log_error "Invalid project name. Please use lowercase letters, numbers, and underscores only, starting with a letter."
            fi
        done
        
        # Prompt for organization ID with validation
        while true; do
            read -p "Enter organization ID (reverse domain, e.g., com.example): " org_id
            
            # Validate org ID (should be a reverse domain format)
            if [[ "${org_id}" =~ ^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$ ]]; then
                break
            else
                log_error "Invalid organization ID. Please use reverse domain format (e.g., com.example)."
            fi
        done
        
        # Save the new values to config for future use
        set_config "FLUTTER_PROJECT_NAME" "${project_name}"
        set_config "FLUTTER_ORG_ID" "${org_id}"
    fi

    # Confirm the details
    echo ""
    log_info "You're about to create a Flutter project with the following details:"
    log_info "Project name: ${project_name}"
    log_info "Organization ID: ${org_id}"
    
    read -p "Proceed? (yes/no): " proceed
    if [[ "${proceed}" != "yes" && "${proceed}" != "y" ]]; then
        log_info "Operation cancelled."
        return 0
    fi
    
    # Create the Flutter project
    log_info "Creating Flutter project..."
    flutter create --org "${org_id}" "${project_name}"
    
    # Check if the project was created successfully
    if [[ $? -ne 0 ]]; then
        log_error "Failed to create Flutter project."
        return 1
    fi
    
    # Add a message about the next steps
    log_success "Flutter project created successfully!"
    log_info "Project directory: $(pwd)/${project_name}"
    
    # Navigate to the project directory
    cd "${project_name}" || {
        log_error "Failed to change to project directory."
        log_info "The project was created, but we couldn't navigate to it."
        log_info "You can set up flavors and CI/CD manually by running:"
        log_info "  cd ${project_name}"
        log_info "  ../bin/dev-cli.sh flutter flavors"
        log_info "  ../bin/dev-cli.sh flutter cicd"
        return 1
    }
    
    # Offer additional setup options
    echo ""
    log_section "Additional Setup Options"
    log_info "Choose what you want to include in your Flutter project '${project_name}':"
    
    # Flavor setup option
    read -p "Do you want to set up flavors? (yes/no): " setup_flavors
    if [[ "${setup_flavors}" == "yes" || "${setup_flavors}" == "y" ]]; then
        setup_flutter_flavors "${project_name}" "${org_id}"
    else
        log_info "Skipping flavor setup. You can set up flavors later by running:"
        log_info "  cd ${project_name}"
        log_info "  ../bin/dev-cli.sh flutter flavors"
    fi
    
    # CI/CD setup option
    read -p "Do you want to set up CI/CD with Fastlane? (yes/no): " setup_cicd
    if [[ "${setup_cicd}" == "yes" || "${setup_cicd}" == "y" ]]; then
        setup_flutter_cicd "${project_name}" "${org_id}"
    else
        log_info "Skipping CI/CD setup. You can set up CI/CD later by running:"
        log_info "  cd ${project_name}"
        log_info "  ../bin/dev-cli.sh flutter cicd"
    fi
    
    echo ""
    log_info "Next steps:"
    log_info "1. Navigate to your project: cd ${project_name}"
    log_info "2. Run your app: flutter run"
    
    # Set Flutter as the selected framework
    set_config "SELECTED_FRAMEWORK" "flutter"
    
    return 0
}

# Function to set up Flutter flavors
function setup_flutter_flavors() {
    local project_name="${1:-}"
    local org_id="${2:-}"
    local selected_flavors=()
    
    log_section "Flutter Flavor Setup"
    log_info "Setting up flavors for your Flutter project..."
    
    # Check if pubspec.yaml exists in the current directory
    if [[ ! -f "pubspec.yaml" ]]; then
        log_error "No pubspec.yaml found in the current directory. Please run this command from a Flutter project directory."
        log_info "If you're using the CLI to create a new project, flavors will be set up after the project is created."
        return 1
    fi
    
    # Try to get the project name from pubspec.yaml if not provided
    if [[ -z "${project_name}" ]]; then
        project_name=$(grep -m 1 "name:" pubspec.yaml | awk '{print $2}' | tr -d "'\"")
        if [[ -z "${project_name}" ]]; then
            log_error "Could not determine project name from pubspec.yaml"
            read -p "Please enter the project name: " project_name
            if [[ -z "${project_name}" ]]; then
                log_error "Project name is required for flavor setup."
                return 1
            fi
        fi
    fi
    
    # Try to determine organization ID from android/app/build.gradle if available
    if [[ -z "${org_id}" ]]; then
        if [[ -f "android/app/build.gradle" ]]; then
            org_id=$(grep -m 1 "applicationId" android/app/build.gradle | awk -F'"' '{print $2}')
        fi
    fi
    
    # If still not found, try to get it from Info.plist
    if [[ -z "${org_id}" && -f "ios/Runner/Info.plist" ]]; then
        org_id=$(grep -A 1 "CFBundleIdentifier" ios/Runner/Info.plist | grep string | awk -F'>' '{print $2}' | awk -F'<' '{print $1}')
    fi
    
    # If still not found, prompt the user
    if [[ -z "${org_id}" ]]; then
        read -p "Enter organization ID (e.g., com.example): " org_id
        if [[ -z "${org_id}" ]]; then
            log_error "Organization ID is required for flavor setup."
            return 1
        fi
    fi
    
    echo "Select which flavors you want to set up:"
    
    # Dev flavor
    read -p "Include dev flavor? (yes/no): " include_dev
    if [[ "${include_dev}" == "yes" || "${include_dev}" == "y" ]]; then
        selected_flavors+=("dev")
    fi
    
    # QA flavor
    read -p "Include qa flavor? (yes/no): " include_qa
    if [[ "${include_qa}" == "yes" || "${include_qa}" == "y" ]]; then
        selected_flavors+=("qa")
    fi
    
    # UAT flavor
    read -p "Include uat flavor? (yes/no): " include_uat
    if [[ "${include_uat}" == "yes" || "${include_uat}" == "y" ]]; then
        selected_flavors+=("uat")
    fi
    
    # Prod flavor
    read -p "Include prod flavor? (yes/no): " include_prod
    if [[ "${include_prod}" == "yes" || "${include_prod}" == "y" ]]; then
        selected_flavors+=("prod")
    fi
    
    if [ ${#selected_flavors[@]} -eq 0 ]; then
        log_warning "No flavors selected. Skipping flavor setup."
        return 0
    fi
    
    log_info "Setting up flavors: ${selected_flavors[*]}"
    
    # Update pubspec.yaml to add flavor config and flutter_flavorizr
    log_info "Updating pubspec.yaml to add flavor support..."
    
    # Add flutter_flavorizr package as dev dependency
    flutter pub add flutter_flavorizr --dev
    
    # Create a temporary file to modify pubspec.yaml
    TEMP_PUBSPEC=$(mktemp)
    
    # Read pubspec.yaml and add flavor configurations
    {
        # Read pubspec.yaml line by line until dev_dependencies section
        in_dev_dependencies=false
        while IFS= read -r line; do
            echo "$line"
            if [[ "$line" == "dev_dependencies:"* ]]; then
                in_dev_dependencies=true
            elif [[ "$in_dev_dependencies" == true && "$line" =~ ^[a-z] ]]; then
                # We've moved past dev_dependencies, add flavorizr config
                in_dev_dependencies=false
                echo ""
                echo "# Flavor configuration"
                echo "flavorizr:"
                echo "  app:"
                echo "    android:"
                echo "      flavorDimensions: \"flavor-type\""
                echo "    ios: {}"
                echo ""
                echo "  flavors:"
                
                # Add each selected flavor
                for flavor in "${selected_flavors[@]}"; do
                    case "$flavor" in
                        dev)
                            echo "    dev:"
                            echo "      app:"
                            echo "        name: \"${project_name} Dev\""
                            echo "      android:"
                            echo "        applicationId: \"${org_id}.${project_name}.dev\""
                            echo "      ios:"
                            echo "        bundleId: \"${org_id}.${project_name}.dev\""
                            ;;
                        qa)
                            echo "    qa:"
                            echo "      app:"
                            echo "        name: \"${project_name} QA\""
                            echo "      android:"
                            echo "        applicationId: \"${org_id}.${project_name}.qa\""
                            echo "      ios:"
                            echo "        bundleId: \"${org_id}.${project_name}.qa\""
                            ;;
                        uat)
                            echo "    uat:"
                            echo "      app:"
                            echo "        name: \"${project_name} UAT\""
                            echo "      android:"
                            echo "        applicationId: \"${org_id}.${project_name}.uat\""
                            echo "      ios:"
                            echo "        bundleId: \"${org_id}.${project_name}.uat\""
                            ;;
                        prod)
                            echo "    prod:"
                            echo "      app:"
                            echo "        name: \"${project_name}\""
                            echo "      android:"
                            echo "        applicationId: \"${org_id}.${project_name}\""
                            echo "      ios:"
                            echo "        bundleId: \"${org_id}.${project_name}\""
                            ;;
                    esac
                done
            fi
        done < pubspec.yaml
    } > "$TEMP_PUBSPEC"
    
    # Replace the original pubspec.yaml with our modified version
    mv "$TEMP_PUBSPEC" pubspec.yaml
    
    # Run flutter pub get to update dependencies
    flutter pub get
    
    # Run flutter_flavorizr to generate flavor configurations
    log_info "Generating flavor configurations..."
    flutter pub run flutter_flavorizr
    
    # Create lib/config/environment.dart for configuration management
    mkdir -p lib/config
    
    # Create environment.dart file for managing environments
    cat > lib/config/environment.dart << 'EOF'
enum Environment {
  dev,
  qa,
  uat,
  prod,
}

class AppConfig {
  static late Environment environment;
  static late String apiBaseUrl;
  static late bool enableLogging;

  static void setEnvironment(Environment env) {
    environment = env;
    
    switch (environment) {
      case Environment.dev:
        apiBaseUrl = 'https://dev-api.example.com';
        enableLogging = true;
        break;
      case Environment.qa:
        apiBaseUrl = 'https://qa-api.example.com';
        enableLogging = true;
        break;
      case Environment.uat:
        apiBaseUrl = 'https://uat-api.example.com';
        enableLogging = true;
        break;
      case Environment.prod:
        apiBaseUrl = 'https://api.example.com';
        enableLogging = false;
        break;
    }
  }

  static bool isDev() => environment == Environment.dev;
  static bool isQA() => environment == Environment.qa;
  static bool isUAT() => environment == Environment.uat;
  static bool isProd() => environment == Environment.prod;
}
EOF

    # Update main.dart to handle flavor configuration
    TEMP_MAIN=$(mktemp)
    
    # Read the current main.dart and modify it to include flavor configuration
    {
        cat << 'EOF'
import 'package:flutter/material.dart';
import 'config/environment.dart';

void main() {
  // Default to prod environment if no flavor is selected
  AppConfig.setEnvironment(Environment.prod);
  runApp(const MyApp());
}
EOF
        # Skip the first line (import) and the void main() function from the original file
        sed '1d;/^void main/,/^}/d' lib/main.dart
    } > "$TEMP_MAIN"
    
    # Replace the original main.dart with our modified version
    mv "$TEMP_MAIN" lib/main.dart
    
    # Create flavor-specific main files
    for flavor in "${selected_flavors[@]}"; do
        cat > "lib/main_${flavor}.dart" << EOF
import 'package:flutter/material.dart';
import 'config/environment.dart';
import 'main.dart' as app;

void main() {
  AppConfig.setEnvironment(Environment.${flavor});
  app.main();
}
EOF
    done
    
    # Remove main.dart file as it's not needed with flavors
    if [[ -f "lib/main.dart" ]]; then
        log_info "Removing main.dart file to avoid conflicts with flavor-specific main files..."
        rm "lib/main.dart"
        
        # Update flavor-specific main files to not depend on main.dart
        for flavor in "${selected_flavors[@]}"; do
            cat > "lib/main_${flavor}.dart" << EOF
import 'package:flutter/material.dart';
import 'app.dart';
import 'flavors.dart';

void main() {
  F.appFlavor = Flavor.${flavor};
  runApp(const App());
}
EOF
        done
        
        log_info "Successfully removed main.dart. Flavor-specific main files updated to be independent."
    fi
    
    log_success "Flutter flavors have been set up successfully!"
    log_info "You can now run your app with a specific flavor using:"
    
    for flavor in "${selected_flavors[@]}"; do
        log_info "  flutter run --flavor ${flavor} -t lib/main_${flavor}.dart"
    done
    
    return 0
}

# Function to display CI/CD requirements checklist
function show_cicd_checklist() {
    log_section "CI/CD Requirements Checklist"
    
    log_info "Before proceeding with CI/CD setup, ensure you have the following:"
    
    echo ""
    log_info "✅ CREDENTIALS & ACCESS:"
    log_info "   📱 Android:"
    log_info "      - Google Play Console access (Owner or Release Manager role)"
    log_info "      - Service account JSON key file with proper permissions"
    log_info "      - Keystore file (.jks) for signing the app"
    log_info "      - Keystore credentials (keyAlias, keyPassword, storePassword)"
    
    log_info "   🍏 iOS:"
    log_info "      - Apple Developer Account with App Manager or Admin access"
    log_info "      - App Store Connect API Key OR Apple ID credentials"
    log_info "      - Provisioning profiles & certificates"
    
    echo ""
    log_info "✅ APP METADATA:"
    log_info "   - App name, package name (Android), bundle identifier (iOS)"
    log_info "   - Firebase App ID (if using Firebase App Distribution)"
    log_info "   - Version and build number strategy"
    
    echo ""
    log_info "✅ CI/CD SYSTEM REQUIREMENTS:"
    log_info "   - Flutter SDK installed"
    log_info "   - Java JDK (for Android builds)"
    log_info "   - Xcode CLI tools (for iOS builds, macOS-only)"
    log_info "   - Ruby and Fastlane installed"
    log_info "   - Environment variables securely stored"
    
    echo ""
    log_info "These requirements will be set up as part of this process, but some"
    log_info "items (like Google Play or App Store credentials) must be obtained manually."
    
    # Ask if the user wants to proceed
    read -p "Do you want to proceed with CI/CD setup? (yes/no): " proceed
    if [[ "${proceed}" != "yes" && "${proceed}" != "y" ]]; then
        log_info "CI/CD setup cancelled."
        return 1
    fi
    
    return 0
}

# Function to set up CI/CD with fastlane
function setup_flutter_cicd() {
    # Display the checklist first
    show_cicd_checklist || return 1
    
    local project_name="${1:-}"
    local org_id="${2:-}"
    local platforms=()
    
    log_section "Flutter CI/CD Setup"
    log_info "Setting up CI/CD with Fastlane for your Flutter project..."
    
    # Check if pubspec.yaml exists in the current directory
    if [[ ! -f "pubspec.yaml" ]]; then
        log_error "No pubspec.yaml found in the current directory. Please run this command from a Flutter project directory."
        log_info "If you're using the CLI to create a new project, CI/CD will be set up after the project is created."
        return 1
    fi
    
    # Try to get the project name from pubspec.yaml if not provided
    if [[ -z "${project_name}" ]]; then
        project_name=$(grep -m 1 "name:" pubspec.yaml | awk '{print $2}' | tr -d "'\"")
        if [[ -z "${project_name}" ]]; then
            log_error "Could not determine project name from pubspec.yaml"
            read -p "Please enter the project name: " project_name
            if [[ -z "${project_name}" ]]; then
                log_error "Project name is required for CI/CD setup."
                return 1
            fi
        fi
    fi
    
    # Try to determine organization ID from android/app/build.gradle if available
    if [[ -z "${org_id}" ]]; then
        if [[ -f "android/app/build.gradle" ]]; then
            org_id=$(grep -m 1 "applicationId" android/app/build.gradle | awk -F'"' '{print $2}')
        fi
    fi
    
    # If not found, try to get it from Info.plist
    if [[ -z "${org_id}" && -f "ios/Runner/Info.plist" ]]; then
        org_id=$(grep -A 1 "CFBundleIdentifier" ios/Runner/Info.plist | grep string | awk -F'>' '{print $2}' | awk -F'<' '{print $1}')
    fi
    
    # If still not found, prompt the user
    if [[ -z "${org_id}" ]]; then
        read -p "Enter organization ID (e.g., com.example): " org_id
        if [[ -z "${org_id}" ]]; then
            log_error "Organization ID is required for CI/CD setup."
            return 1
        fi
    fi
    
    echo "In which store do you want to set up CI/CD?"
    
    # Android option
    read -p "Set up for Android (Google Play Store)? (yes/no): " setup_android
    if [[ "${setup_android}" == "yes" || "${setup_android}" == "y" ]]; then
        platforms+=("android")
    fi
    
    # iOS option
    read -p "Set up for iOS (App Store)? (yes/no): " setup_ios
    if [[ "${setup_ios}" == "yes" || "${setup_ios}" == "y" ]]; then
        platforms+=("ios")
    fi
    
    # Firebase App Distribution option
    read -p "Set up for Firebase App Distribution? (yes/no): " setup_firebase
    local use_firebase=false
    if [[ "${setup_firebase}" == "yes" || "${setup_firebase}" == "y" ]]; then
        use_firebase=true
    fi
    
    if [ ${#platforms[@]} -eq 0 ]; then
        log_warning "No platforms selected. Skipping CI/CD setup."
        return 0
    fi
    
    log_info "Setting up CI/CD for platforms: ${platforms[*]}"
    
    # Skip Ruby and Fastlane installation for now, as it can be time-consuming
    read -p "Skip Ruby and Fastlane installation (recommended for faster setup)? (yes/no): " skip_installation
    if [[ "${skip_installation}" != "yes" && "${skip_installation}" != "y" ]]; then
        # Check if Ruby is installed
        if ! command -v ruby &> /dev/null; then
            log_error "Ruby is required for Fastlane. Please install Ruby and try again."
            log_info "You can install Ruby using Homebrew: brew install ruby"
            return 1
        fi
        
        # Check if Fastlane is installed
        if ! command -v fastlane &> /dev/null; then
            log_info "Fastlane is not installed. Installing fastlane..."
            log_info "This may take a few minutes..."
            
            # Install fastlane with helpful feedback
            gem install fastlane || {
                log_error "Fastlane installation failed."
                log_info "You can install it manually later with: gem install fastlane"
                log_info "Continuing with file setup only..."
            }
        fi
        
        # Install required fastlane plugins
        if [[ "${use_firebase}" == true ]]; then
            log_info "Installing fastlane-plugin-firebase_app_distribution..."
            
            # Create a temporary Gemfile for plugin installation
            cat > Gemfile.tmp << 'EOF'
source "https://rubygems.org"
gem "fastlane"
plugins_path = File.join(File.dirname(__FILE__), '.fastlane', 'Pluginfile')
eval_gemfile(plugins_path) if File.exist?(plugins_path)
EOF
            
            # Create .fastlane directory and Pluginfile
            mkdir -p .fastlane
            cat > .fastlane/Pluginfile << 'EOF'
gem 'fastlane-plugin-firebase_app_distribution'
EOF
            
            # Install plugins
            bundle install --gemfile=Gemfile.tmp || {
                log_error "Failed to install fastlane plugins."
                log_info "You can install them manually later."
            }
            
            # Clean up temporary files
            rm -f Gemfile.tmp
        fi
    else
        log_info "Skipping Ruby and Fastlane installation. Files will be set up for later use."
    fi
    
    # Set up for Android
    if [[ " ${platforms[*]} " =~ " android " ]]; then
        log_info "Setting up Fastlane for Android..."
        
        # Create android/fastlane directory
        mkdir -p android/fastlane
        
        # Create Appfile with more comprehensive options
        cat > android/fastlane/Appfile << EOF
# The package name of your application
package_name("${org_id}.${project_name}")

# Path to the Play Store credentials JSON file
# Uncomment the appropriate one:
# For local development:
# json_key_file("path/to/play-store-credentials.json")

# For CI/CD environments (using environment variable):
# json_key_data(ENV['GOOGLE_PLAY_JSON'])
EOF
        
        # Create common .env.example file for reference
        cat > android/.env.example << EOF
# Android Credentials
KEYSTORE_PATH=../key.jks
KEYSTORE_PASSWORD=your_store_password
KEY_ALIAS=your_key_alias
KEY_PASSWORD=your_key_password

# Google Play credentials
GOOGLE_PLAY_JSON=/path/to/play-store-credentials.json

# Firebase
FIREBASE_APP_ID=1:123456789012:android:1234abcd
FIREBASE_TOKEN=your_firebase_cli_token

# Version control
VERSION_NAME=1.0.0
VERSION_CODE=1
EOF
        
        # Create a more comprehensive Fastfile with Firebase support
        cat > android/fastlane/Fastfile << 'EOF'
# Fastlane configuration for Android
default_platform(:android)

# Load environment variables from .env file if it exists
if File.exist?('../.env')
  load_dot_env('../.env')
end

platform :android do
  # Common setup for all lanes
  before_all do
    ensure_git_status_clean unless is_ci
  end

  desc "Increment version code"
  lane :increment_version do
    path = '../app/build.gradle'
    re = /versionCode\s+(\d+)/
    
    s = File.read(path)
    versionCode = s[re, 1].to_i
    s[re, 1] = (versionCode + 1).to_s
    
    File.write(path, s)
    
    UI.message("Incremented version code to #{versionCode + 1}")
  end

  desc "Build and sign APK"
  lane :build do
    # Clean project
    gradle(task: "clean")
    
    # Build the APK
    gradle(
      task: "assemble",
      build_type: "Release",
      properties: {
        "android.injected.signing.store.file" => ENV["KEYSTORE_PATH"],
        "android.injected.signing.store.password" => ENV["KEYSTORE_PASSWORD"],
        "android.injected.signing.key.alias" => ENV["KEY_ALIAS"],
        "android.injected.signing.key.password" => ENV["KEY_PASSWORD"],
      }
    )
  end
  
  desc "Build and sign App Bundle"
  lane :build_bundle do
    # Clean project
    gradle(task: "clean")
    
    # Build the app bundle
    gradle(
      task: "bundle",
      build_type: "Release",
      properties: {
        "android.injected.signing.store.file" => ENV["KEYSTORE_PATH"],
        "android.injected.signing.store.password" => ENV["KEYSTORE_PASSWORD"],
        "android.injected.signing.key.alias" => ENV["KEY_ALIAS"],
        "android.injected.signing.key.password" => ENV["KEY_PASSWORD"],
      }
    )
  end

  desc "Deploy to Firebase App Distribution"
  lane :firebase do
    build
    
    firebase_app_distribution(
      app: ENV["FIREBASE_APP_ID"],
      firebase_cli_token: ENV["FIREBASE_TOKEN"],
      apk_path: "../build/app/outputs/apk/release/app-release.apk",
      release_notes: "New build for testing",
      groups: "testers"
    )
  end

  desc "Deploy to Play Store Internal Testing"
  lane :internal do
    build_bundle
    
    # Upload to Play Store internal testing track
    upload_to_play_store(
      track: "internal",
      aab: "../build/app/outputs/bundle/release/app-release.aab",
      skip_upload_metadata: true,
      skip_upload_images: true,
      skip_upload_screenshots: true
    )
  end

  desc "Deploy to Play Store Beta track"
  lane :beta do
    build_bundle
    
    # Upload to Play Store beta track
    upload_to_play_store(
      track: "beta",
      aab: "../build/app/outputs/bundle/release/app-release.aab",
      skip_upload_metadata: true,
      skip_upload_images: true,
      skip_upload_screenshots: true
    )
  end

  desc "Deploy to Play Store Production"
  lane :production do
    build_bundle
    
    # Upload to Play Store production track
    upload_to_play_store(
      aab: "../build/app/outputs/bundle/release/app-release.aab",
      skip_upload_metadata: true,
      skip_upload_images: true,
      skip_upload_screenshots: true
    )
  end
  
  desc "Validate setup by building in debug mode"
  lane :validate do
    gradle(task: "assemble", build_type: "Debug")
    UI.success("Setup validated! Your Android Fastlane configuration is working.")
  end
  
  # Handle errors
  error do |lane, exception, options|
    # Notify team about failure
    # (Uncomment and customize as needed)
    # slack(
    #   message: "Lane #{lane} failed with error: #{exception.message}",
    #   success: false
    # )
  end
end
EOF
        
        # Create Gemfile with more plugins
        cat > android/Gemfile << 'EOF'
source "https://rubygems.org"

gem "fastlane"
gem "fastlane-plugin-firebase_app_distribution"
EOF

        log_success "Fastlane files have been set up for Android!"
        log_info "To use fastlane for Android deployment:"
        log_info "1. Update credentials in android/.env (see .env.example for reference)"
        log_info "2. For Google Play: Place credentials in android/path/to/play-store-credentials.json"
        log_info "3. For Firebase App Distribution: Configure FIREBASE_APP_ID and FIREBASE_TOKEN"
        log_info "4. Build and deploy with specific lanes:"
        log_info "   cd android && bundle install && bundle exec fastlane [internal|beta|production|firebase]"
    fi
    
    # Set up for iOS
    if [[ " ${platforms[*]} " =~ " ios " ]]; then
        log_info "Setting up Fastlane for iOS..."
        
        # Create ios/fastlane directory
        mkdir -p ios/fastlane
        
        # Create Appfile with more comprehensive options
        cat > ios/fastlane/Appfile << EOF
# Your app's bundle identifier
app_identifier("${org_id}.${project_name}")

# Team configuration
# Uncomment and edit the appropriate options based on your setup:

# OPTION 1: Apple ID and team selection (normal Apple ID)
# apple_id("your_apple_id@example.com")
# team_id("YOUR_TEAM_ID")
# itc_team_id("YOUR_ITC_TEAM_ID")

# OPTION 2: App Store Connect API Key (recommended for CI/CD)
# app_store_connect_api_key(
#   key_id: ENV['ASC_KEY_ID'],
#   issuer_id: ENV['ASC_ISSUER_ID'],
#   key_filepath: ENV['ASC_KEY_FILEPATH'],
# )
EOF
        
        # Create .env.example file for iOS
        cat > ios/.env.example << EOF
# iOS Signing & API Credentials
ASC_KEY_ID=AB123456
ASC_ISSUER_ID=12345678-1234-1234-1234-123456789012
ASC_KEY_FILEPATH=./AuthKey_AB123456.p8
APPLE_ID=your_apple_id@example.com
TEAM_ID=AB12345678
ITC_TEAM_ID=12345678

# Match credentials (if using match for signing)
MATCH_PASSWORD=your_match_encryption_password
MATCH_GIT_URL=https://github.com/yourusername/certificates.git

# Firebase
FIREBASE_APP_ID=1:123456789012:ios:1234abcd
FIREBASE_TOKEN=your_firebase_cli_token

# Version control
VERSION_NUMBER=1.0.0
BUILD_NUMBER=1
EOF
        
        # Create a more comprehensive Fastfile
        cat > ios/fastlane/Fastfile << 'EOF'
# Fastlane configuration for iOS
default_platform(:ios)

# Load environment variables from .env file if it exists
if File.exist?('../.env')
  load_dot_env('../.env')
end

platform :ios do
  # Common setup for all lanes
  before_all do
    ensure_git_status_clean unless is_ci
  end

  desc "Increment build number"
  lane :increment_build do
    increment_build_number(
      xcodeproj: "Runner.xcodeproj"
    )
  end

  desc "Update version number"
  lane :update_version do |options|
    if options[:version]
      increment_version_number(
        version_number: options[:version],
        xcodeproj: "Runner.xcodeproj"
      )
    end
  end

  desc "Fetch signing certificates"
  lane :certificates do
    # Uncomment and customize one of these signing options

    # OPTION 1: Using match (recommended for teams)
    # match(
    #   type: "appstore",
    #   app_identifier: ENV["APP_IDENTIFIER"],
    #   username: ENV["APPLE_ID"],
    #   team_id: ENV["TEAM_ID"],
    #   git_url: ENV["MATCH_GIT_URL"],
    #   readonly: is_ci
    # )

    # OPTION 2: Manual certificates
    # (Will use certificates from your keychain)
  end

  desc "Build the Flutter iOS app"
  lane :build do
    # Ensure code signing is set up
    certificates
    
    # Build the app using gym
    gym(
      workspace: "Runner.xcworkspace",
      scheme: "Runner",
      clean: true,
      export_method: "app-store",
      export_options: {
        provisioningProfiles: {
          ENV["APP_IDENTIFIER"] => "match AppStore #{ENV['APP_IDENTIFIER']}"
        }
      },
      # If using Flutter build IPA, use this instead:
      # skip_build_archive: true,
      # archive_path: "../build/ios/archive/Runner.xcarchive"
    )
  end

  desc "Deploy to Firebase App Distribution"
  lane :firebase do
    build
    
    firebase_app_distribution(
      app: ENV["FIREBASE_APP_ID"],
      firebase_cli_token: ENV["FIREBASE_TOKEN"],
      ipa_path: "../build/ios/ipa/Runner.ipa",
      release_notes: "New build for testing",
      groups: "testers"
    )
  end

  desc "Deploy to TestFlight"
  lane :beta do
    build
    
    # Upload to TestFlight
    pilot(
      skip_waiting_for_build_processing: true,
      skip_submission: true,
      distribute_external: false
    )
  end

  desc "Deploy to App Store Connect for review"
  lane :app_store_review do
    build
    
    # Upload to App Store Connect for review
    deliver(
      submit_for_review: true,
      automatic_release: false,
      force: true,
      skip_metadata: false,
      skip_screenshots: true,
      skip_binary_upload: false
    )
  end

  desc "Deploy to App Store"
  lane :production do
    build
    
    # Upload to App Store
    deliver(
      submit_for_review: true,
      automatic_release: true,
      force: true,
      skip_metadata: false,
      skip_screenshots: true,
      skip_binary_upload: false,
      precheck_include_in_app_purchases: false
    )
  end
  
  desc "Validate setup by building in debug mode"
  lane :validate do
    # Simple Xcode build to validate setup
    gym(
      workspace: "Runner.xcworkspace",
      scheme: "Runner",
      clean: true,
      skip_archive: true,
      configuration: "Debug"
    )
    UI.success("Setup validated! Your iOS Fastlane configuration is working.")
  end
  
  # Error handling
  error do |lane, exception, options|
    # Notify team about failure
    # (Uncomment and customize as needed)
    # slack(
    #   message: "Lane #{lane} failed with error: #{exception.message}",
    #   success: false
    # )
  end
end
EOF
        
        # Create Gemfile
        cat > ios/Gemfile << 'EOF'
source "https://rubygems.org"

gem "fastlane"
gem "cocoapods"
gem "fastlane-plugin-firebase_app_distribution"
EOF

        log_success "Fastlane files have been set up for iOS!"
        log_info "To use fastlane for iOS deployment:"
        log_info "1. Update credentials in ios/.env (see .env.example for reference)"
        log_info "2. Set up App Store Connect API key or Apple ID credentials in ios/fastlane/Appfile"
        log_info "3. Configure code signing (using match or manual certificates)"
        log_info "4. Build and deploy with specific lanes:"
        log_info "   cd ios && bundle install && bundle exec fastlane [beta|app_store_review|production|firebase]"
    fi
    
    # Create CI/CD examples for common CI systems
    mkdir -p .github/workflows
    
    # Create GitHub Actions workflow
    cat > .github/workflows/flutter-ci.yml << 'EOF'
name: Flutter CI/CD

on:
  push:
    branches: [ main ]
    tags: [ 'v*' ]
  pull_request:
    branches: [ main ]

jobs:
  # Test job
  test:
    name: Run Tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.19.0'
          channel: 'stable'
      - name: Install dependencies
        run: flutter pub get
      - name: Run tests
        run: flutter test

  # Android build job
  build_android:
    name: Build Android
    runs-on: ubuntu-latest
    needs: test
    # Only run on tag pushes or manually
    if: startsWith(github.ref, 'refs/tags/v') || github.event_name == 'workflow_dispatch'
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-java@v3
        with:
          distribution: 'temurin'
          java-version: '17'
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.19.0'
          channel: 'stable'
      - name: Install dependencies
        run: flutter pub get
      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.0'
          bundler-cache: true
      - name: Install Fastlane
        run: gem install fastlane
      - name: Setup keystore
        run: |
          echo "${{ secrets.KEYSTORE_BASE64 }}" | base64 --decode > android/app/key.jks
          echo "KEYSTORE_PATH=key.jks" >> android/.env
          echo "KEYSTORE_PASSWORD=${{ secrets.KEYSTORE_PASSWORD }}" >> android/.env
          echo "KEY_ALIAS=${{ secrets.KEY_ALIAS }}" >> android/.env
          echo "KEY_PASSWORD=${{ secrets.KEY_PASSWORD }}" >> android/.env
          echo "${{ secrets.GOOGLE_PLAY_JSON }}" > android/play-store-credentials.json
          echo "GOOGLE_PLAY_JSON=play-store-credentials.json" >> android/.env
      - name: Build and deploy
        run: |
          cd android
          bundle install
          if [[ "${{ github.ref }}" == "refs/tags/v"* ]]; then
            bundle exec fastlane production
          else
            bundle exec fastlane beta
          fi

  # iOS build job
  build_ios:
    name: Build iOS
    runs-on: macos-latest
    needs: test
    # Only run on tag pushes or manually
    if: startsWith(github.ref, 'refs/tags/v') || github.event_name == 'workflow_dispatch'
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.19.0'
          channel: 'stable'
          architecture: x64
      - name: Install dependencies
        run: flutter pub get
      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.0'
          bundler-cache: true
      - name: Install Fastlane
        run: gem install fastlane
      - name: Setup iOS signing
        run: |
          echo "APP_IDENTIFIER=${{ secrets.APP_IDENTIFIER }}" >> ios/.env
          echo "APPLE_ID=${{ secrets.APPLE_ID }}" >> ios/.env
          echo "TEAM_ID=${{ secrets.TEAM_ID }}" >> ios/.env
          echo "ITC_TEAM_ID=${{ secrets.ITC_TEAM_ID }}" >> ios/.env
          echo "${{ secrets.APP_STORE_CONNECT_API_KEY }}" > ios/app_store_connect_api_key.p8
          echo "ASC_KEY_FILEPATH=app_store_connect_api_key.p8" >> ios/.env
          echo "ASC_KEY_ID=${{ secrets.ASC_KEY_ID }}" >> ios/.env
          echo "ASC_ISSUER_ID=${{ secrets.ASC_ISSUER_ID }}" >> ios/.env
      - name: Build and deploy
        run: |
          cd ios
          bundle install
          if [[ "${{ github.ref }}" == "refs/tags/v"* ]]; then
            bundle exec fastlane production
          else
            bundle exec fastlane beta
          fi
EOF

    # Create Jenkins example file
    cat > Jenkinsfile.example << 'EOF'
pipeline {
    agent any
    
    environment {
        FLUTTER_HOME = tool 'flutter'  // Assume Flutter is installed as a Jenkins tool
        PATH = "$FLUTTER_HOME/bin:$PATH"
    }
    
    stages {
        stage('Setup') {
            steps {
                sh 'flutter --version'
                sh 'flutter pub get'
            }
        }
        
        stage('Test') {
            steps {
                sh 'flutter test'
            }
        }
        
        stage('Build Android') {
            when {
                expression { return params.DEPLOY_ANDROID == true }
            }
            steps {
                withCredentials([
                    file(credentialsId: 'android-keystore', variable: 'KEYSTORE_PATH'),
                    string(credentialsId: 'keystore-password', variable: 'KEYSTORE_PASSWORD'),
                    string(credentialsId: 'key-alias', variable: 'KEY_ALIAS'),
                    string(credentialsId: 'key-password', variable: 'KEY_PASSWORD'),
                    file(credentialsId: 'google-play-api-key', variable: 'GOOGLE_PLAY_JSON')
                ]) {
                    sh '''
                        cd android
                        bundle install
                        bundle exec fastlane beta
                    '''
                }
            }
        }
        
        stage('Build iOS') {
            when {
                expression { return params.DEPLOY_IOS == true }
            }
            agent { label 'mac' }  // Requires a macOS agent
            steps {
                withCredentials([
                    string(credentialsId: 'apple-id', variable: 'APPLE_ID'),
                    string(credentialsId: 'team-id', variable: 'TEAM_ID'),
                    string(credentialsId: 'itc-team-id', variable: 'ITC_TEAM_ID'),
                    file(credentialsId: 'app-store-connect-api-key', variable: 'ASC_KEY_FILEPATH'),
                    string(credentialsId: 'asc-key-id', variable: 'ASC_KEY_ID'),
                    string(credentialsId: 'asc-issuer-id', variable: 'ASC_ISSUER_ID')
                ]) {
                    sh '''
                        cd ios
                        bundle install
                        bundle exec fastlane beta
                    '''
                }
            }
        }
    }
    
    post {
        always {
            // Archive test results and artifacts
            archiveArtifacts artifacts: 'build/app/outputs/**/*.apk', allowEmptyArchive: true
            archiveArtifacts artifacts: 'build/ios/ipa/*.ipa', allowEmptyArchive: true
        }
        success {
            echo 'Build successful!'
        }
        failure {
            echo 'Build failed!'
        }
    }
}
EOF
    
    # Create a README section with setup and usage instructions
    log_info "Adding CI/CD documentation to README.md..."
    cat >> README.md << 'EOF'

## CI/CD with Fastlane

This project uses Fastlane for CI/CD to automate the deployment process.

### Prerequisites Checklist

#### 🔐 Credentials & Access
- **Android:**
  - [ ] Google Play Console Access (Owner/Release Manager)
  - [ ] Service account JSON key with proper permissions
  - [ ] Keystore file (.jks) and credentials
  
- **iOS:**
  - [ ] Apple Developer Account with proper access
  - [ ] App Store Connect API Key OR Apple ID credentials
  - [ ] Provisioning profiles & certificates
  - [ ] App ID & Bundle ID

#### 📱 App Metadata
- [ ] App name, package name, bundle identifier
- [ ] Firebase App ID (if using Firebase)
- [ ] Version and build number strategy

#### 💾 Project Structure
- [ ] Flutter source code with proper folder structure
- [ ] Fastlane setup for Android and iOS
- [ ] Environment variables or .env files

#### 🧰 CI/CD Requirements
- [ ] Flutter SDK installed
- [ ] Java JDK (for Android)
- [ ] Xcode CLI tools (for iOS, macOS-only)
- [ ] Ruby and Fastlane installed
- [ ] Secure environment variables

### Android Deployment

1. Set up environment variables (see `.env.example`):
   ```bash
   cp android/.env.example android/.env
   # Edit .env with your credentials
   ```

2. Build and deploy:
   ```bash
   cd android
   bundle install
   bundle exec fastlane [internal|beta|production|firebase]
   ```

### iOS Deployment

1. Set up environment variables (see `.env.example`):
   ```bash
   cp ios/.env.example ios/.env
   # Edit .env with your credentials
   ```

2. Build and deploy:
   ```bash
   cd ios
   bundle install
   bundle exec fastlane [beta|app_store_review|production|firebase]
   ```

### CI/CD Integration

This project includes examples for:
- GitHub Actions (.github/workflows/flutter-ci.yml)
- Jenkins (Jenkinsfile.example)

To set up CI/CD:

1. Set up the required secrets/credentials in your CI system
2. Configure the workflow to trigger on your preferred events (tags, branches)
3. Ensure your CI runner has the necessary dependencies installed

See the documentation for your CI system for more details on how to configure these secrets.
EOF
    
    log_success "CI/CD setup with Fastlane has been completed!"
    log_info "Fastlane configuration files have been created and enhanced with:"
    log_info "- Comprehensive credential management with .env files"
    log_info "- Multiple deployment targets (TestFlight, App Store, Play Store, Firebase)"
    log_info "- GitHub Actions and Jenkins pipeline examples"
    log_info "- Detailed documentation and checklists in README.md"
    
    return 0
}

# Show Flutter help
function show_flutter_help() {
    log_info "Flutter Commands:"
    log_info "  create             Create a new Flutter project"
    log_info "  flavors            Set up Flutter flavors"
    log_info "  cicd               Set up CI/CD with Fastlane"
    log_info "  checklist          Display CI/CD requirements checklist"
    log_info ""
    log_info "Examples:"
    log_info "  dev-cli flutter create"
    log_info "  dev-cli flutter flavors"
    log_info "  dev-cli flutter cicd"
    log_info "  dev-cli flutter checklist"
}

# Execute the main function with all arguments
handle_flutter_operations "$@" 