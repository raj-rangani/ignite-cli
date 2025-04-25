#!/bin/bash

# This script updates dev-cli.sh to call flutter-project.sh when Flutter is selected

# Make sure the flutter-project.sh script exists
if [[ ! -f "./flutter-project.sh" ]]; then
    echo "Error: flutter-project.sh not found in the current directory."
    exit 1
fi

# Make sure dev-cli.sh exists
if [[ ! -f "./dev-cli.sh" ]]; then
    echo "Error: dev-cli.sh not found in the current directory."
    exit 1
fi

# Create a backup if it doesn't already exist
if [[ ! -f "./dev-cli.sh.original" ]]; then
    echo "Creating backup of dev-cli.sh as dev-cli.sh.original"
    cp dev-cli.sh dev-cli.sh.original
fi

# Find the lines to replace
FLUTTER_START=$(grep -n "framework=\"flutter\"" dev-cli.sh | head -1 | cut -d: -f1)
if [[ -z "$FLUTTER_START" ]]; then
    echo "Error: Could not find Flutter framework selection in dev-cli.sh"
    exit 1
fi

# Find the next line after the Flutter case section (the line with ";;")
FLUTTER_END=$(tail -n +$FLUTTER_START dev-cli.sh | grep -n ";;" | head -1 | cut -d: -f1)
FLUTTER_END=$((FLUTTER_START + FLUTTER_END - 1))

echo "Found Flutter framework selection at lines $FLUTTER_START-$FLUTTER_END"

# Create temporary file
TMP_FILE=$(mktemp)

# Copy the beginning of the file up to but not including the Flutter selection
head -n $((FLUTTER_START - 1)) dev-cli.sh > "$TMP_FILE"

# Append the modified Flutter selection code
cat >> "$TMP_FILE" << 'EOF'
                        framework="flutter"
                        # If Flutter is selected, run the Flutter project creation script
                        if [[ -f "${SCRIPT_DIR}/flutter-project.sh" ]]; then
                            log_info "Running Flutter project setup..."
                            "${SCRIPT_DIR}/flutter-project.sh"
                        else
                            log_error "Flutter project setup script not found."
                        fi
                        ;;
EOF

# Append the rest of the file after the Flutter section
tail -n +$((FLUTTER_END + 1)) dev-cli.sh >> "$TMP_FILE"

# Replace the original with the modified file
cp "$TMP_FILE" dev-cli.sh

# Make sure the file is executable
chmod +x dev-cli.sh

# Clean up
rm "$TMP_FILE"

echo "Successfully updated dev-cli.sh to call flutter-project.sh"