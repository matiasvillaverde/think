#!/bin/bash

# Create App Store Connect Version
# Uses the existing submit-app.sh infrastructure but only creates versions

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
PLATFORM="all"
VERSION=""

# Function to show usage
show_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -p, --platform PLATFORM Platform to manage (ios, macos, visionos, all)"
    echo "  -v, --version VERSION   Version number to create (default: current marketing version)"
    echo "  --dry-run              Show what would be done without making changes"
    echo "  -h, --help             Show this help message"
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

# Get version if not specified
if [ -z "$VERSION" ]; then
    VERSION=$(get_marketing_version)
    echo -e "${BLUE}Using current marketing version: $VERSION${NC}"
fi

# Function to get bundle ID for platform
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

# Function to get platform API name
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

# Function to create version for a platform
create_version() {
    local platform="$1"
    local bundle_id=$(get_bundle_id "$platform")
    local app_id=$(get_app_id "$platform")
    local api_platform=$(get_platform_api_name "$platform")
    
    echo -e "${BLUE}Creating version $VERSION for $platform...${NC}"
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}DRY RUN: Would create version $VERSION for $platform${NC}"
        echo "         Bundle ID: $bundle_id"
        echo "         App ID: $app_id"
        echo "         Platform: $api_platform"
        return 0
    fi
    
    # Check if appstore-api.sh exists
    if [ ! -f "$SCRIPT_DIR/appstore-api.sh" ]; then
        echo -e "${RED}Error: appstore-api.sh not found${NC}"
        return 1
    fi
    
    # Create version using the same API as submit-app.sh
    echo -e "${BLUE}Checking existing versions...${NC}"
    
    # Get existing versions
    local versions_response=$("$SCRIPT_DIR/appstore-api.sh" list-versions "$app_id" 2>/dev/null || echo "")
    
    # Check if version already exists
    local version_exists=$(echo "$versions_response" | jq -r ".data[] | select(.attributes.versionString == \"$VERSION\" and .attributes.platform == \"$api_platform\") | .id" 2>/dev/null || echo "")
    
    if [ -n "$version_exists" ]; then
        echo -e "${YELLOW}Version $VERSION already exists for $platform${NC}"
        return 0
    fi
    
    # Create the version
    echo -e "${BLUE}Creating new version...${NC}"
    local create_response=$("$SCRIPT_DIR/appstore-api.sh" create-version "$app_id" "$VERSION" "$api_platform" 2>&1)
    
    # Debug: Show the actual response
    if [ -n "$DEBUG" ]; then
        echo -e "${YELLOW}DEBUG: API Response:${NC}"
        echo "$create_response"
    fi
    
    # Check if successful
    if echo "$create_response" | grep -q '"errors"'; then
        local error_detail=$(echo "$create_response" | jq -r '.errors[0].detail' 2>/dev/null || echo "Unknown error")
        if echo "$error_detail" | grep -q "already been created"; then
            echo -e "${YELLOW}Version $VERSION already exists for $platform${NC}"
        else
            echo -e "${RED}Error creating version: $error_detail${NC}"
            echo -e "${RED}Full response: $create_response${NC}"
            return 1
        fi
    elif echo "$create_response" | grep -q "API Error"; then
        echo -e "${RED}API authentication error${NC}"
        echo "$create_response"
        return 1
    else
        echo -e "${GREEN}✓ Version $VERSION created for $platform${NC}"
    fi
}

# Main execution
main() {
    echo -e "${BLUE}App Store Connect Version Creator${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════${NC}"
    echo ""
    
    if [ "$PLATFORM" = "all" ]; then
        for p in ios macos visionos; do
            create_version "$p"
            echo ""
        done
    else
        create_version "$PLATFORM"
    fi
    
    echo ""
    echo -e "${GREEN}✅ Version creation complete!${NC}"
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}This was a dry run. No changes were made.${NC}"
    fi
}

# Run main function
main
