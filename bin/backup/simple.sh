#!/bin/bash

# Define a test command that uses braces for error handling
function test_command() {
    local cmd="$1"
    
    echo "Running command: $cmd"
    
    # Try syntax 1 - with normal braces
    bash -c "$cmd" || {
        echo "Command failed. Trying fallback."
        bash -c "echo Fallback command"
    }
    
    # Try syntax 2 - using an if statement
    if ! bash -c "$cmd"; then
        echo "Command failed. Trying fallback."
        bash -c "echo Fallback command"
    fi
}

# Test the function
test_command "echo Hello, world!"
test_command "false"