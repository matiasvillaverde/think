#!/bin/bash

# Script to automate translation of Localizable.xcstrings files using AITranslate
# Requirements:
# - Downloads the AITranslate repository
# - Finds all Localizable.xcstrings files in ../Think directory
# - Uses API key and languages from .env file
# - Runs translation on each file
# - Add an .env
# OPENAI_API_KEY=your-openai-api-key-here
# LANGUAGES=es,en,fr,de,it,ja,etc

set -e  # Exit on any error

# Function to get absolute path compatible with macOS and Linux
get_abs_path() {
    local path="$1"
    if [[ "$path" = /* ]]; then
        echo "$path"
    else
        echo "$(cd "$(dirname "$path")" && pwd)/$(basename "$path")"
    fi
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to print section headers
print_header() {
    echo ""
    echo "==================================="
    echo "$1"
    echo "==================================="
}

# Check required commands
print_header "Checking required tools"
for cmd in git swift; do
    if ! command_exists "$cmd"; then
        echo "Error: '$cmd' command not found. Please install it and try again."
        exit 1
    fi
done
echo "✓ All required tools are available"

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load environment variables from .env file
print_header "Loading environment variables"
if [ -f "${SCRIPT_DIR}/.env" ]; then
    echo "Loading variables from .env file..."
    source "${SCRIPT_DIR}/.env"
else
    echo "Error: .env file not found in script directory."
    exit 1
fi

# Check if required environment variables are set
if [ -z "$OPENAI_API_KEY" ]; then
    echo "Error: OPENAI_API_KEY not found in .env file."
    exit 1
fi

if [ -z "$LANGUAGES" ]; then
    echo "Error: LANGUAGES not found in .env file."
    exit 1
fi

echo "✓ API key loaded successfully"
echo "✓ Languages to translate: $LANGUAGES"

# Clone AITranslate repository if it doesn't exist
print_header "Setting up AITranslate repository"
REPO_DIR="${SCRIPT_DIR}/AITranslate"
if [ ! -d "$REPO_DIR" ]; then
    echo "Cloning AITranslate repository..."
    git clone https://github.com/pmacro/AITranslate.git "$REPO_DIR"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to clone the repository."
        exit 1
    fi
else
    echo "AITranslate repository already exists. Updating..."
    cd "$REPO_DIR"
    git pull
    if [ $? -ne 0 ]; then
        echo "Warning: Failed to update the repository."
        echo "Continuing with existing repository..."
    fi
fi

# Build the AITranslate tool
cd "$REPO_DIR"
print_header "Building AITranslate"
echo "Running swift build..."
swift build
if [ $? -ne 0 ]; then
    echo "Error: Failed to build AITranslate."
    exit 1
fi
echo "✓ Build completed successfully"

# Find all Localizable.xcstrings files in specified modules
print_header "Searching for localization files"
BASE_DIR=$(get_abs_path "${SCRIPT_DIR}/..")

# Define the modules to search
MODULES=("Abstractions" "AudioGenerator" "Context" "Database" "Factories" "AgentOrchestrator" "Think" "RAG" "UIComponents" "ViewModels")

echo "Searching for Localizable.xcstrings files in modules: ${MODULES[*]}"

# Collect all Localizable.xcstrings files from specified modules
FILES=""
MISSING_MODULES=""
for MODULE in "${MODULES[@]}"; do
    # Check multiple possible locations for each module
    POSSIBLE_PATHS=(
        "${BASE_DIR}/${MODULE}/Sources/${MODULE}/Resources/Localizable.xcstrings"  # Swift package structure
        "${BASE_DIR}/${MODULE}/Localizable.xcstrings"  # App structure (for Think main app)
    )
    
    FOUND=false
    for PATH in "${POSSIBLE_PATHS[@]}"; do
        if [ -f "$PATH" ]; then
            echo "✓ Found: $PATH"
            if [ -z "$FILES" ]; then
                FILES="$PATH"
            else
                FILES="$FILES"$'\n'"$PATH"
            fi
            FOUND=true
            break  # Found the file for this module, move to next module
        fi
    done
    
    if [ "$FOUND" = false ]; then
        echo "⚠️  Warning: No Localizable.xcstrings found for module: $MODULE"
        if [ -z "$MISSING_MODULES" ]; then
            MISSING_MODULES="$MODULE"
        else
            MISSING_MODULES="$MISSING_MODULES, $MODULE"
        fi
    fi
done

# Check if any files were found
if [ -z "$FILES" ]; then
    echo "Error: No Localizable.xcstrings files found in any of the specified modules."
    exit 1
fi

# Process each file
# Count files using a more portable approach
FILE_COUNT=0
IFS=$'\n'
for F in $FILES; do
    FILE_COUNT=$((FILE_COUNT + 1))
done
unset IFS
echo "✓ Found $FILE_COUNT Localizable.xcstrings files"

# Handle interruptions
trap 'echo -e "\n⚠️ Script interrupted. Exiting..."; exit 1' INT TERM

# Counter for progress tracking
COUNTER=0
SUCCESSFUL=0
FAILED=0

print_header "Starting translation process"
IFS=$'\n'
for FILE in $FILES; do
    COUNTER=$((COUNTER + 1))
    echo "[$COUNTER/$FILE_COUNT] Processing: $FILE"
    cd "$REPO_DIR"
    
    # Run the translation command with the API key from .env
    swift run ai-translate "$FILE" -o "$OPENAI_API_KEY" -v -l "$LANGUAGES"
    
    if [ $? -ne 0 ]; then
        echo "⚠️ Warning: Failed to translate $FILE. Continuing with next file..."
        FAILED=$((FAILED + 1))
        continue
    fi
    
    SUCCESSFUL=$((SUCCESSFUL + 1))
    echo "✓ Completed translation for $FILE"
    echo "------------------------"
done
unset IFS

print_header "Translation summary"
echo "Total files processed: $FILE_COUNT"
echo "Successful translations: $SUCCESSFUL"
echo "Failed translations: $FAILED"

if [ -n "$MISSING_MODULES" ]; then
    echo ""
    echo "Modules without Localizable.xcstrings: $MISSING_MODULES"
fi

if [ $FAILED -eq 0 ]; then
    echo "✓ All translations completed successfully!"
else
    echo "⚠️ Some translations failed. Please check the logs above."
fi