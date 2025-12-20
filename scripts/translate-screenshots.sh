#!/bin/bash

# Script to translate a single Localizable.xcstrings file using AITranslate
# Requirements:
# - Translates only ../App-Screenshots/Localizable.xcstrings
# - Uses API key from .env file
# - Uses hardcoded list of languages
# - Clones AITranslate repository if it doesn't exist

set -e  # Exit on any error

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
    echo "Loading API key from .env file..."
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

# Hardcoded languages from your list
LANGUAGES="ar-SA,ca,cs,da,de-DE,el,en-AU,en-CA,en,en-GB,en-US,es-ES,es-MX,fi,fr-CA,fr-FR,he,hi,hr,hu,id,it,ja,ko,ms,nl-NL,no,pl,pt-BR,pt-PT,ro,ru,sk,sv,th,tr,uk,vi,zh-Hans,zh-Hant"

echo "✓ API key loaded successfully"
echo "✓ Using hardcoded languages: $LANGUAGES"

# Set AITranslate repository path
print_header "Setting up AITranslate repository"
REPO_DIR="${SCRIPT_DIR}/AITranslate"
if [ ! -d "$REPO_DIR" ]; then
    echo "Error: AITranslate repository not found at ${REPO_DIR}"
    echo "Please ensure the repository is already cloned before running this script."
    exit 1
fi
echo "✓ Using existing AITranslate repository at ${REPO_DIR}"

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

# Set the target file path
TARGET_FILE="$(cd "$SCRIPT_DIR" && cd .. && pwd)/App-Screenshots/Localizable.xcstrings"

# Check if the target file exists
print_header "Checking target file"
if [ ! -f "$TARGET_FILE" ]; then
    echo "Error: Target file not found: $TARGET_FILE"
    exit 1
fi

echo "✓ Target file exists: $TARGET_FILE"

# Handle interruptions
trap 'echo -e "\n⚠️ Script interrupted. Exiting..."; exit 1' INT TERM

print_header "Starting translation process"
echo "Translating: $TARGET_FILE"
cd "$REPO_DIR"

# Run the translation command with the API key from .env
swift run ai-translate "$TARGET_FILE" -o "$OPENAI_API_KEY" -v -l "$LANGUAGES"

if [ $? -ne 0 ]; then
    echo "⚠️ Error: Failed to translate $TARGET_FILE."
    exit 1
fi

print_header "Translation summary"
echo "✓ Translation completed successfully for: $TARGET_FILE"
echo "✓ Translated to languages: $LANGUAGES"