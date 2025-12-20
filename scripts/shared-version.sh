#!/bin/bash
# Shared version management for Think
# Manages CFBundleShortVersionString and CFBundleVersion across all platforms

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Info.plist files for all platforms
PLIST_IOS="$PROJECT_ROOT/Think/Info.plist"
PLIST_VISION="$PROJECT_ROOT/Think Vision/Info.plist"
# macOS uses the iOS plist (universal app)
PLIST_MACOS="$PLIST_IOS"

# Function to get version from plist
get_version() {
    local plist="$1"
    local key="$2"
    
    if [ ! -f "$plist" ]; then
        echo ""
        return 1
    fi
    
    plutil -extract "$key" raw "$plist" 2>/dev/null || echo ""
}

# Function to set version in plist
set_version() {
    local plist="$1"
    local key="$2"
    local value="$3"
    
    if [ ! -f "$plist" ]; then
        echo -e "${RED}Error: $plist not found${NC}" >&2
        return 1
    fi
    
    plutil -replace "$key" -string "$value" "$plist"
}

# Function to get current marketing version (e.g., 2.0.5)
get_marketing_version() {
    local version=$(get_version "$PLIST_IOS" "CFBundleShortVersionString")
    if [ -z "$version" ]; then
        version="1.0.0"
    fi
    echo "$version"
}

# Function to get current build number (e.g., 50)
get_build_number() {
    local build=$(get_version "$PLIST_IOS" "CFBundleVersion")
    if [ -z "$build" ]; then
        build="1"
    fi
    echo "$build"
}

# Function to set marketing version across all plists
set_marketing_version() {
    local version="$1"
    
    # Only show output if not called from bump_version
    if [ -z "$SILENT_MODE" ]; then
        echo -e "${BLUE}Setting marketing version to: $version${NC}"
    fi
    
    # Use agvtool to set marketing version
    cd "$PROJECT_ROOT"
    agvtool new-marketing-version "$version" >/dev/null 2>&1
    
    if [ -z "$SILENT_MODE" ]; then
        echo -e "${GREEN}✓ Marketing version updated to $version${NC}"
    fi
}

# Function to set build number across all plists
set_build_number() {
    local build="$1"
    
    echo -e "${BLUE}Setting build number to: $build${NC}"
    
    # Use agvtool to set build number
    cd "$PROJECT_ROOT"
    agvtool new-version -all "$build" >/dev/null 2>&1
    
    echo -e "${GREEN}✓ Build number updated to $build${NC}"
}

# Function to increment build number
increment_build_number() {
    # Use agvtool to increment build number
    cd "$PROJECT_ROOT"
    agvtool next-version -all >/dev/null 2>&1
    
    # Get the new build number
    local new=$(get_build_number)
    echo "$new"
}

# Function to bump version component
bump_version() {
    local component="$1"  # major, minor, or patch
    local current=$(get_marketing_version)
    
    # Split version into components
    IFS='.' read -r major minor patch <<< "$current"
    
    # Ensure we have all components
    major=${major:-0}
    minor=${minor:-0}
    patch=${patch:-0}
    
    case "$component" in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
        *)
            echo -e "${RED}Error: Unknown version component: $component${NC}" >&2
            echo "Use: major, minor, or patch" >&2
            return 1
            ;;
    esac
    
    local new_version="$major.$minor.$patch"
    
    # Set silent mode for cleaner output
    SILENT_MODE=1 set_marketing_version "$new_version"
    
    # Also increment build number
    increment_build_number > /dev/null
    
    echo "$new_version"
}

# Function to display current versions
show_versions() {
    echo -e "${BLUE}Current Version Information${NC}"
    echo "=========================="
    echo ""
    
    local marketing=$(get_marketing_version)
    local build=$(get_build_number)
    
    echo -e "Marketing Version: ${GREEN}$marketing${NC}"
    echo -e "Build Number: ${GREEN}$build${NC}"
    echo ""
    
    # Check consistency across plists
    local ios_marketing=$(get_version "$PLIST_IOS" "CFBundleShortVersionString")
    local ios_build=$(get_version "$PLIST_IOS" "CFBundleVersion")
    local vision_marketing=$(get_version "$PLIST_VISION" "CFBundleShortVersionString")
    local vision_build=$(get_version "$PLIST_VISION" "CFBundleVersion")
    
    if [ "$ios_marketing" != "$vision_marketing" ] || [ "$ios_build" != "$vision_build" ]; then
        echo -e "${YELLOW}⚠️  Warning: Version mismatch detected${NC}"
        echo "iOS/macOS: $ios_marketing ($ios_build)"
        echo "visionOS:  $vision_marketing ($vision_build)"
        echo ""
        echo "Run '$0 sync' to synchronize versions"
    else
        echo -e "${GREEN}✓ All platforms synchronized${NC}"
    fi
}

# Function to sync versions across all plists
sync_versions() {
    local marketing=$(get_marketing_version)
    local build=$(get_build_number)
    
    echo -e "${BLUE}Synchronizing versions across all platforms...${NC}"
    
    set_marketing_version "$marketing"
    set_build_number "$build"
    
    echo -e "${GREEN}✓ Synchronization complete${NC}"
}

# Function to calculate new version after bump
bump_version() {
    local current_version="$1"
    local bump_type="$2"
    
    # Parse current version
    IFS='.' read -ra VERSION_PARTS <<< "$current_version"
    local major="${VERSION_PARTS[0]}"
    local minor="${VERSION_PARTS[1]}"
    local patch="${VERSION_PARTS[2]}"
    
    # Apply bump
    case "$bump_type" in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
        *)
            echo -e "${RED}Error: Invalid bump type: $bump_type${NC}" >&2
            return 1
            ;;
    esac
    
    # Return new version
    echo "${major}.${minor}.${patch}"
}

# Function to validate version format
validate_version() {
    local version="$1"
    
    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${RED}Error: Invalid version format: $version${NC}" >&2
        echo "Expected format: X.Y.Z (e.g., 2.0.5)" >&2
        return 1
    fi
    
    return 0
}

# Main command handler - only run if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    case "${1:-show}" in
    show)
        show_versions
        ;;
    get-marketing)
        get_marketing_version
        ;;
    get-build)
        get_build_number
        ;;
    set-marketing)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: Version required${NC}" >&2
            echo "Usage: $0 set-marketing <version>" >&2
            exit 1
        fi
        validate_version "$2"
        set_marketing_version "$2"
        ;;
    set-build)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: Build number required${NC}" >&2
            echo "Usage: $0 set-build <number>" >&2
            exit 1
        fi
        set_build_number "$2"
        ;;
    increment-build)
        increment_build_number
        ;;
    bump)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: Component required${NC}" >&2
            echo "Usage: $0 bump <major|minor|patch>" >&2
            exit 1
        fi
        current=$(get_marketing_version)
        new_version=$(bump_version "$current" "$2")
        set_marketing_version "$new_version"
        increment_build_number
        echo -e "${GREEN}Bumped to version $new_version${NC}"
        ;;
    sync)
        sync_versions
        ;;
    *)
        echo "Think Version Manager"
        echo "========================"
        echo ""
        echo "Usage: $0 <command> [args]"
        echo ""
        echo "Commands:"
        echo "  show                Show current versions (default)"
        echo "  get-marketing       Get marketing version (e.g., 2.0.5)"
        echo "  get-build          Get build number (e.g., 50)"
        echo "  set-marketing <ver> Set marketing version"
        echo "  set-build <num>    Set build number"
        echo "  increment-build    Increment build number by 1"
        echo "  bump <component>   Bump version (major|minor|patch)"
        echo "  sync               Sync versions across all platforms"
        echo ""
        echo "Examples:"
        echo "  $0 show"
        echo "  $0 bump patch"
        echo "  $0 set-marketing 2.1.0"
        echo "  $0 increment-build"
        exit 1
        ;;
    esac
fi