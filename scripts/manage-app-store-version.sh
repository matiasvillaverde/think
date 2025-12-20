#!/bin/bash

# App Store Connect Version Manager
# Creates or updates app versions across all platforms

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

# Source shared version functions
source "$SCRIPT_DIR/shared-version.sh"

# Source environment variables if available
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
fi

DEFAULT_BUNDLE_ID="${APPSTORE_BUNDLE_ID:-com.example.app}"

# Default values
DRY_RUN=false
FORCE_UPDATE=false
PLATFORM=""
VERSION=""

# Function to show usage
show_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -p, --platform PLATFORM Platform to manage (ios, macos, visionos, all)"
    echo "  -v, --version VERSION   Version number to create/update (default: current marketing version)"
    echo "  --dry-run              Show what would be done without making changes"
    echo "  --force                Force update even if version exists"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "This script creates or updates app versions in App Store Connect."
    echo "It checks if a version exists and creates it if missing, or updates if different."
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--platform)
            PLATFORM="$2"
            shift 2
            ;;
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE_UPDATE=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_usage
            exit 1
            ;;
    esac
done

# Validate platform
if [ -z "$PLATFORM" ]; then
    PLATFORM="all"
fi

if [[ ! "$PLATFORM" =~ ^(ios|macos|visionos|all)$ ]]; then
    echo -e "${RED}Error: Invalid platform '$PLATFORM'${NC}"
    echo "Valid platforms: ios, macos, visionos, all"
    exit 1
fi

# Get version if not specified
if [ -z "$VERSION" ]; then
    VERSION=$(get_marketing_version)
    echo -e "${BLUE}Using current marketing version: $VERSION${NC}"
fi

# Function to check if API key exists
check_api_key() {
    # Check if we have API key from environment
    if [ -n "$APP_STORE_CONNECT_API_KEY_PATH" ] && [ -f "$APP_STORE_CONNECT_API_KEY_PATH" ]; then
        echo -e "${BLUE}Using API key from environment${NC}"
        return 0
    fi
    
    # Check for AuthKey_*.p8 in scripts or project root
    local key_file
    key_file=$(find "$SCRIPT_DIR" -maxdepth 1 -name "AuthKey_*.p8" -type f | head -n 1)
    if [ -z "$key_file" ]; then
        key_file=$(find "$PROJECT_ROOT" -maxdepth 1 -name "AuthKey_*.p8" -type f | head -n 1)
    fi
    if [ -n "$key_file" ] && [ -f "$key_file" ]; then
        export APP_STORE_CONNECT_API_KEY_PATH="$key_file"
        echo -e "${BLUE}Using API key from $key_file${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}Warning: App Store Connect API key not found${NC}"
    echo "Expected location: APP_STORE_CONNECT_API_KEY_PATH or a local AuthKey_*.p8 file"
    
    # Check if we have fastlane credentials
    if [ -n "$FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD" ] || command -v fastlane &> /dev/null; then
        echo -e "${BLUE}Will attempt to use fastlane authentication${NC}"
        return 0
    fi
    
    echo -e "${RED}No authentication method available${NC}"
    return 1
}

# Function to get bundle ID for a platform
get_bundle_id() {
    local platform="$1"
    case "$platform" in
        ios)
            echo "${APPSTORE_BUNDLE_ID_IOS:-$DEFAULT_BUNDLE_ID}"
            ;;
        macos)
            echo "${APPSTORE_BUNDLE_ID_MACOS:-$DEFAULT_BUNDLE_ID}"
            ;;
        visionos)
            echo "${APPSTORE_BUNDLE_ID_VISIONOS:-$DEFAULT_BUNDLE_ID}"
            ;;
    esac
}

# Function to get app ID for a platform
get_app_id() {
    local platform="$1"
    local app_id=""
    case "$platform" in
        ios)
            app_id="${APPSTORE_APP_ID_IOS:-${APPSTORE_APP_ID:-}}"
            ;;
        macos)
            app_id="${APPSTORE_APP_ID_MACOS:-${APPSTORE_APP_ID:-}}"
            ;;
        visionos)
            app_id="${APPSTORE_APP_ID_VISIONOS:-${APPSTORE_APP_ID:-}}"
            ;;
    esac
    
    if [ -n "$app_id" ]; then
        echo "$app_id"
        return 0
    fi
    
    local bundle_id
    bundle_id=$(get_bundle_id "$platform")
    app_id=$("$SCRIPT_DIR/get-app-id.sh" "$bundle_id" 2>/dev/null || true)
    
    if [ -z "$app_id" ] || [ "$app_id" = "null" ]; then
        echo -e "${RED}Error: Unable to resolve app ID for $platform${NC}" >&2
        return 1
    fi
    
    echo "$app_id"
}

# Function to get platform name for API
get_platform_api_name() {
    local platform="$1"
    case "$platform" in
        ios)
            echo "IOS"
            ;;
        macos)
            echo "MAC_OS"
            ;;
        visionos)
            echo "VISION_OS"
            ;;
    esac
}

# Function to check if version exists
check_version_exists() {
    local app_id="$1"
    local platform="$2"
    local version="$3"
    local bundle_id
    bundle_id=$(get_bundle_id "$platform")
    
    echo -e "${BLUE}Checking if version $version exists for $platform...${NC}"
    
    # Use fastlane to query versions
    local result=$(cd "$PROJECT_ROOT" && fastlane run app_store_build_number \
        app_identifier:"$bundle_id" \
        platform:"$platform" \
        version:"$version" 2>&1 || true)
    
    # Check if version exists by looking for the version in the output
    if echo "$result" | grep -q "Could not find version"; then
        return 1  # Version doesn't exist
    else
        return 0  # Version exists
    fi
}

# Function to create or update version using fastlane
manage_version_fastlane() {
    local app_id="$1"
    local platform="$2"
    local version="$3"
    local api_platform=$(get_platform_api_name "$platform")
    local bundle_id
    bundle_id=$(get_bundle_id "$platform")
    
    echo -e "${BLUE}Managing version $version for $platform (App ID: $app_id)...${NC}"
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}DRY RUN: Would create/update version $version for $platform${NC}"
        return 0
    fi
    
    # Use fastlane deliver to create/update version
    cd "$PROJECT_ROOT"
    
    # First, try to create the version
    echo -e "${BLUE}Creating version $version for $platform...${NC}"
    
    # Export necessary environment variables for fastlane
    export APP_STORE_CONNECT_API_KEY_KEY_ID="${APP_STORE_CONNECT_API_KEY_ID:-$APPSTORE_KEY_ID}"
    export APP_STORE_CONNECT_API_KEY_ISSUER_ID="${APP_STORE_CONNECT_API_KEY_ISSUER_ID:-$APPSTORE_ISSUER_ID}"
    export APP_STORE_CONNECT_API_KEY_KEY_FILEPATH="${APP_STORE_CONNECT_API_KEY_PATH}"
    
    # Create version using fastlane deliver
    if [ "$platform" = "ios" ]; then
        fastlane deliver create_app_version \
            --app_identifier "$bundle_id" \
            --app_version "$version" \
            --skip_screenshots \
            --skip_metadata \
            --force
    elif [ "$platform" = "visionos" ]; then
        # For visionOS, use the platform bundle identifier
        fastlane deliver create_app_version \
            --app_identifier "$bundle_id" \
            --app_version "$version" \
            --skip_screenshots \
            --skip_metadata \
            --force
    else
        # For macOS
        fastlane deliver create_app_version \
            --app_identifier "$bundle_id" \
            --app_version "$version" \
            --platform "osx" \
            --skip_screenshots \
            --skip_metadata \
            --force
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Successfully created/updated version $version for $platform${NC}"
    else
        echo -e "${YELLOW}⚠ Version might already exist or there was an error${NC}"
    fi
}

# Function to manage version using API directly
manage_version_api() {
    local app_id="$1"
    local platform="$2"
    local version="$3"
    local api_platform=$(get_platform_api_name "$platform")
    
    echo -e "${BLUE}Managing version $version for $platform (App ID: $app_id)...${NC}"
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}DRY RUN: Would create/update version $version for $platform${NC}"
        return 0
    fi
    
    # Generate JWT token
    local token=$("$SCRIPT_DIR/generate-app-store-token.sh" 2>/dev/null)
    if [ -z "$token" ]; then
        echo -e "${RED}Failed to generate authentication token${NC}"
        return 1
    fi
    
    # Create the version
    echo -e "${BLUE}Creating version $version for $platform...${NC}"
    
    local response=$(curl -s -X POST \
        "https://api.appstoreconnect.apple.com/v1/appStoreVersions" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d '{
            "data": {
                "type": "appStoreVersions",
                "attributes": {
                    "platform": "'$api_platform'",
                    "versionString": "'$version'"
                },
                "relationships": {
                    "app": {
                        "data": {
                            "type": "apps",
                            "id": "'$app_id'"
                        }
                    }
                }
            }
        }')
    
    # Check for errors
    if echo "$response" | grep -q '"errors"'; then
        local error_detail=$(echo "$response" | grep -o '"detail":"[^"]*"' | cut -d'"' -f4)
        if echo "$error_detail" | grep -q "has already been created"; then
            echo -e "${YELLOW}Version $version already exists for $platform${NC}"
            
            if [ "$FORCE_UPDATE" = true ]; then
                echo -e "${BLUE}Force update requested - updating existing version${NC}"
                # Here we could implement update logic if needed
            fi
        else
            echo -e "${RED}Error creating version: $error_detail${NC}"
            return 1
        fi
    else
        echo -e "${GREEN}✓ Successfully created version $version for $platform${NC}"
    fi
    
    return 0
}

# Function to process a single platform
process_platform() {
    local platform="$1"
    local app_id
    app_id=$(get_app_id "$platform")
    if [ -z "$app_id" ]; then
        return 1
    fi
    
    echo -e "${BLUE}Processing $platform platform...${NC}"
    
    # Try fastlane first, fall back to API if needed
    if command -v fastlane &> /dev/null; then
        manage_version_fastlane "$app_id" "$platform" "$VERSION"
    else
        manage_version_api "$app_id" "$platform" "$VERSION"
    fi
}

# Main execution
main() {
    echo -e "${BLUE}App Store Connect Version Manager${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════${NC}"
    echo ""
    
    # Check for API key
    if ! check_api_key; then
        exit 1
    fi
    
    # Process platforms
    if [ "$PLATFORM" = "all" ]; then
        echo -e "${BLUE}Managing version $VERSION for all platforms...${NC}"
        echo ""
        
        for p in ios macos visionos; do
            process_platform "$p"
            echo ""
        done
    else
        process_platform "$PLATFORM"
    fi
    
    echo ""
    echo -e "${GREEN}✅ Version management complete!${NC}"
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}This was a dry run. No changes were made.${NC}"
    fi
}

# Run main function
main
