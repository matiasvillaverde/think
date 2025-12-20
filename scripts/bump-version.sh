#!/bin/bash
# Version bump wrapper for Think
# Provides simple interface for version management

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to show usage
usage() {
    echo "Version Bump Script"
    echo "=================="
    echo ""
    echo "Usage: $0 [component]"
    echo ""
    echo "Components:"
    echo "  major   Bump major version (1.0.0 -> 2.0.0)"
    echo "  minor   Bump minor version (1.0.0 -> 1.1.0)"
    echo "  patch   Bump patch version (1.0.0 -> 1.0.1) [default]"
    echo "  build   Increment build number only"
    echo ""
    echo "Examples:"
    echo "  $0           # Bump patch version and build"
    echo "  $0 patch     # Bump patch version and build"
    echo "  $0 minor     # Bump minor version and build"
    echo "  $0 major     # Bump major version and build"
    echo "  $0 build     # Increment build number only"
    echo ""
    echo "Current version:"
    "$SCRIPT_DIR/shared-version.sh" show
    exit 1
}

# Get component from argument
COMPONENT="${1:-patch}"

# Handle help
if [ "$COMPONENT" = "-h" ] || [ "$COMPONENT" = "--help" ] || [ "$COMPONENT" = "help" ]; then
    usage
fi

# Show current version
echo -e "${BLUE}Current version:${NC}"
CURRENT_MARKETING=$("$SCRIPT_DIR/shared-version.sh" get-marketing)
CURRENT_BUILD=$("$SCRIPT_DIR/shared-version.sh" get-build)
echo "Marketing: $CURRENT_MARKETING"
echo "Build: $CURRENT_BUILD"
echo ""

# Perform the bump
case "$COMPONENT" in
    major|minor|patch)
        echo -e "${BLUE}Bumping $COMPONENT version...${NC}"
        NEW_VERSION=$("$SCRIPT_DIR/shared-version.sh" bump "$COMPONENT")
        NEW_BUILD=$("$SCRIPT_DIR/shared-version.sh" get-build)
        
        echo ""
        echo -e "${GREEN}✓ Version bumped!${NC}"
        echo "Marketing: $CURRENT_MARKETING → $NEW_VERSION"
        echo "Build: $CURRENT_BUILD → $NEW_BUILD"
        
        # Git operations (optional)
        if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
            echo ""
            echo -e "${YELLOW}Git operations:${NC}"
            
            # Check if we have changes to commit
            if ! git diff --quiet "Think/Info.plist" "Think Vision/Info.plist" 2>/dev/null; then
                echo "Modified files:"
                git status --porcelain "Think/Info.plist" "Think Vision/Info.plist"
                
                echo ""
                echo "To commit these changes:"
                echo "  git add Think/Info.plist \"Think Vision/Info.plist\""
                echo "  git commit -m \"chore: bump version to $NEW_VERSION (build $NEW_BUILD)\""
                echo ""
                echo "To create a release tag:"
                echo "  git tag -a \"v$NEW_VERSION\" -m \"Release version $NEW_VERSION\""
                echo "  git push origin \"v$NEW_VERSION\""
            fi
        fi
        ;;
        
    build)
        echo -e "${BLUE}Incrementing build number...${NC}"
        NEW_BUILD=$("$SCRIPT_DIR/shared-version.sh" increment-build)
        
        echo ""
        echo -e "${GREEN}✓ Build number incremented!${NC}"
        echo "Build: $CURRENT_BUILD → $NEW_BUILD"
        ;;
        
    *)
        echo -e "${RED}Error: Unknown component: $COMPONENT${NC}" >&2
        echo "" >&2
        usage
        ;;
esac