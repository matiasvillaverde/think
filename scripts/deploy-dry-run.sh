#!/bin/bash

# Deploy Dry Run Script
# Shows what the deploy command would do without executing

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
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

# Function to check file existence
check_file() {
    local file="$1"
    local description="$2"
    if [ -f "$file" ]; then
        echo -e "    ${GREEN}✓${NC} $description exists"
    else
        echo -e "    ${RED}✗${NC} $description missing"
    fi
}

# Function to check directory existence
check_directory() {
    local dir="$1"
    local description="$2"
    if [ -d "$dir" ]; then
        echo -e "    ${GREEN}✓${NC} $description exists"
    else
        echo -e "    ${RED}✗${NC} $description missing"
    fi
}

# Function to check command availability
check_command() {
    local cmd="$1"
    local description="$2"
    if command -v "$cmd" &> /dev/null; then
        echo -e "    ${GREEN}✓${NC} $description available"
    else
        echo -e "    ${RED}✗${NC} $description not found"
    fi
}

# Function to check environment variable
check_env_var() {
    local var_name="$1"
    local description="$2"
    if [ -n "${!var_name}" ]; then
        echo -e "    ${GREEN}✓${NC} $description is set"
    else
        echo -e "    ${RED}✗${NC} $description not set"
    fi
}

# Function to simulate command execution
simulate_command() {
    local command="$1"
    local description="$2"
    echo -e "    ${GRAY}→ Would execute: $command${NC}"
    if [ -n "$description" ]; then
        echo -e "      ${CYAN}($description)${NC}"
    fi
}

# Main dry run function
main() {
    cd "$PROJECT_ROOT"
    
    echo -e "${BLUE}🔍 Deploy Dry Run Analysis${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Get current version info
    local current_version=$(get_marketing_version)
    local current_build=$(get_build_number)
    echo -e "${YELLOW}Current Version:${NC} $current_version (Build $current_build)"
    echo -e "${CYAN}Note: The actual deployment will bump version based on commits${NC}"
    echo ""
    
    # Check git status
    echo -e "${YELLOW}Git Status:${NC}"
    local git_status=$(git status --porcelain)
    if [ -z "$git_status" ]; then
        echo -e "    ${GREEN}✓${NC} Working directory clean"
    else
        echo -e "    ${YELLOW}⚠${NC}  Uncommitted changes:"
        echo "$git_status" | sed 's/^/        /'
    fi
    
    local current_branch=$(git branch --show-current)
    echo -e "    ${BLUE}ℹ${NC}  Current branch: $current_branch"
    echo ""
    
    # Step 1: Environment Verification
    echo -e "${YELLOW}1️⃣  Environment Verification${NC}"
    check_command "xcodebuild" "Xcode command line tools"
    check_command "agvtool" "Apple Generic Versioning Tool"
    check_command "xcrun" "Xcode runner"
    check_command "xcrun iTMSTransporter" "App Store submission tool (iTMSTransporter)"
    check_command "xcrun notarytool" "Notarization tool"
    check_env_var "APPSTORE_KEY_ID" "App Store Connect API Key ID"
    check_env_var "APPSTORE_ISSUER_ID" "App Store Connect Issuer ID"
    check_env_var "APP_STORE_CONNECT_API_KEY_PATH" "API key file path"
    check_env_var "TEAM_ID" "Development team ID"
    echo ""
    
    # Step 2: Release Readiness
    echo -e "${YELLOW}2️⃣  Release Readiness${NC}"
    simulate_command "make verify-release" "Check uncommitted changes and API key"
    echo ""
    
    # Step 3: Build Environment Recording
    echo -e "${YELLOW}3️⃣  Build Environment Recording${NC}"
    simulate_command "./scripts/record-environment.sh record" "Save build configuration"
    echo -e "    ${CYAN}Would record:${NC}"
    echo -e "      • macOS version: $(sw_vers -productVersion)"
    echo -e "      • Xcode version: $(xcodebuild -version | head -1)"
    echo -e "      • Git commit: $(git rev-parse --short HEAD)"
    echo -e "      • Version: $current_version ($current_build)"
    echo ""
    
    # Step 4: Platform Builds
    echo -e "${YELLOW}4️⃣  Platform Builds${NC}"
    echo -e "  ${BLUE}iOS:${NC}"
    simulate_command "make archive-ios" "Create iOS archive"
    simulate_command "make export-ios" "Export iOS IPA"
    check_directory "$PROJECT_ROOT/build/archives" "Archive directory"
    
    echo -e "  ${BLUE}macOS:${NC}"
    simulate_command "make archive-macos" "Create macOS archive"
    simulate_command "make export-macos" "Export macOS app"
    simulate_command "make create-dmg-macos" "Create DMG installer"
    
    echo -e "  ${BLUE}visionOS:${NC}"
    simulate_command "make archive-visionos" "Create visionOS archive"
    simulate_command "make export-visionos" "Export visionOS app"
    echo ""
    
    # Step 5: Expected Outputs
    echo -e "${YELLOW}5️⃣  Expected Build Outputs${NC}"
    echo -e "  ${BLUE}Archives:${NC}"
    echo -e "    • build/archives/Think-iOS.xcarchive"
    echo -e "    • build/archives/Think-macOS.xcarchive"
    echo -e "    • build/archives/ThinkVision-visionOS.xcarchive"
    
    echo -e "  ${BLUE}Exports:${NC}"
    echo -e "    • build/export/ios/Think.ipa"
    echo -e "    • build/export/macos/Think.app"
    echo -e "    • build/export/visionos/ThinkVision.ipa"
    echo -e "    • build/dmg/Think-$current_version.dmg"
    echo ""
    
    # Step 6: Changelog Generation
    echo -e "${YELLOW}6️⃣  Changelog Generation${NC}"
    simulate_command "make generate-changelog" "Create release notes"
    echo -e "    ${CYAN}Would analyze commits since last tag for changelog${NC}"
    echo ""
    
    # Step 7: GitHub Release
    echo -e "${YELLOW}7️⃣  GitHub Release${NC}"
    simulate_command "./scripts/create-github-release.sh -v $current_version" "Create GitHub release"
    echo -e "    ${CYAN}Would upload:${NC}"
    echo -e "      • iOS IPA"
    echo -e "      • macOS DMG"
    echo -e "      • visionOS IPA"
    echo ""
    
    # Step 8: App Store Connect Version Management
    echo -e "${YELLOW}8️⃣  App Store Connect Version Management${NC}"
    simulate_command "./scripts/manage-app-store-version.sh -p all" "Create/update versions"
    echo -e "    ${CYAN}Would ensure version $current_version exists for:${NC}"
    echo -e "      • iOS platform"
    echo -e "      • macOS platform"
    echo -e "      • visionOS platform"
    echo ""
    
    # Step 9: App Store Submissions
    echo -e "${YELLOW}9️⃣  App Store Connect Submissions${NC}"
    echo -e "    ${CYAN}Would prompt for confirmation before submitting each platform${NC}"
    echo -e "  ${BLUE}iOS:${NC}"
    simulate_command "./scripts/submit-app.sh -a build/archives/Think-iOS.xcarchive -p ios"
    echo -e "  ${BLUE}macOS:${NC}"
    simulate_command "./scripts/submit-app.sh -a build/archives/Think-macOS.xcarchive -p macos"
    echo -e "  ${BLUE}visionOS:${NC}"
    simulate_command "./scripts/submit-app.sh -a build/archives/ThinkVision-visionOS.xcarchive -p visionos"
    echo ""
    
    # Summary
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Summary:${NC}"
    echo -e "  • Version to deploy: $current_version (Build $current_build)"
    echo -e "  • Platforms: iOS, macOS, visionOS"
    echo -e "  • Total estimated time: 30-45 minutes"
    echo -e "  • Requires manual confirmations for App Store submissions"
    echo ""
    
    # Check for potential issues
    local has_issues=false
    echo -e "${YELLOW}Potential Issues:${NC}"
    
    local key_file=""
    if [ -n "$APP_STORE_CONNECT_API_KEY_PATH" ] && [ -f "$APP_STORE_CONNECT_API_KEY_PATH" ]; then
        key_file="$APP_STORE_CONNECT_API_KEY_PATH"
    else
        key_file=$(find "$SCRIPT_DIR" -maxdepth 1 -name "AuthKey_*.p8" -type f | head -n 1)
        if [ -z "$key_file" ]; then
            key_file=$(find "$PROJECT_ROOT" -maxdepth 1 -name "AuthKey_*.p8" -type f | head -n 1)
        fi
    fi
    
    if [ -z "$key_file" ]; then
        echo -e "  ${RED}⚠${NC}  Missing App Store Connect API key"
        has_issues=true
    fi
    
    if [ -n "$git_status" ]; then
        echo -e "  ${YELLOW}⚠${NC}  Uncommitted changes present"
        has_issues=true
    fi
    
    if [ "$current_branch" != "main" ]; then
        echo -e "  ${YELLOW}⚠${NC}  Not on main branch (current: $current_branch)"
        has_issues=true
    fi
    
    if [ "$has_issues" = false ]; then
        echo -e "  ${GREEN}✓${NC} No issues detected"
    fi
    echo ""
    
    echo -e "${CYAN}This is a dry run. No actions were performed.${NC}"
    echo -e "${CYAN}To execute the actual deployment, run: make deploy${NC}"
}

# Run main function
main
