#!/bin/bash
# Create GitHub release with assets
# Uploads app archives and generates release notes

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

# Default values
VERSION=""
TAG=""
DRAFT=false
PRERELEASE=false
GENERATE_NOTES=true
TITLE=""
NOTES_FILE=""
ASSETS=()

# Function to show usage
usage() {
    echo "GitHub Release Creator"
    echo "====================="
    echo ""
    echo "Usage: $0 -v <version> [options]"
    echo ""
    echo "Required:"
    echo "  -v, --version <version>   Version to release (e.g., 2.0.6)"
    echo ""
    echo "Options:"
    echo "  -t, --tag <tag>          Tag name (default: v<version>)"
    echo "  -T, --title <title>      Release title (default: 'Think <version>')"
    echo "  -n, --notes <file>       Release notes file (default: generate from commits)"
    echo "  -a, --asset <file>       Asset file to upload (can be specified multiple times)"
    echo "  -d, --draft              Create as draft release"
    echo "  -p, --prerelease         Mark as pre-release"
    echo "  --no-generate-notes      Don't auto-generate release notes"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -v 2.0.6"
    echo "  $0 -v 2.0.6 -a build/export/ios/Think.ipa"
    echo "  $0 -v 2.0.6 -d -a build/dmg/Think-2.0.6.dmg"
    echo ""
    echo "Note: Requires GITHUB_TOKEN environment variable"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -t|--tag)
            TAG="$2"
            shift 2
            ;;
        -T|--title)
            TITLE="$2"
            shift 2
            ;;
        -n|--notes)
            NOTES_FILE="$2"
            shift 2
            ;;
        -a|--asset)
            ASSETS+=("$2")
            shift 2
            ;;
        -d|--draft)
            DRAFT=true
            shift
            ;;
        -p|--prerelease)
            PRERELEASE=true
            shift
            ;;
        --no-generate-notes)
            GENERATE_NOTES=false
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo -e "${RED}Error: Unknown option $1${NC}" >&2
            usage
            ;;
    esac
done

# Check required parameters
if [ -z "$VERSION" ]; then
    echo -e "${RED}Error: Version is required${NC}" >&2
    usage
fi

# Set defaults
if [ -z "$TAG" ]; then
    TAG="v$VERSION"
fi

if [ -z "$TITLE" ]; then
    TITLE="Think $VERSION"
fi

# Check if gh is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}Error: GitHub CLI (gh) is not installed${NC}" >&2
    echo "Install with: brew install gh" >&2
    exit 1
fi

# Check GitHub authentication
if ! gh auth status &> /dev/null; then
    echo -e "${RED}Error: Not authenticated with GitHub${NC}" >&2
    echo "Run: gh auth login" >&2
    exit 1
fi

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}Error: Not in a git repository${NC}" >&2
    exit 1
fi

# Ensure we're on the main branch
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "main" ] && [ "$CURRENT_BRANCH" != "master" ]; then
    echo -e "${YELLOW}Warning: Not on main branch (current: $CURRENT_BRANCH)${NC}"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
fi

# Check if tag already exists
if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo -e "${RED}Error: Tag $TAG already exists${NC}" >&2
    echo "Delete with: git tag -d $TAG && git push origin :refs/tags/$TAG" >&2
    exit 1
fi

# Generate release notes if needed
if [ -z "$NOTES_FILE" ] && [ "$GENERATE_NOTES" = true ]; then
    echo -e "${BLUE}Generating release notes...${NC}"
    
    # Get the previous tag
    PREV_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    
    # Generate changelog for this release
    TEMP_NOTES=$(mktemp)
    if [ -n "$PREV_TAG" ]; then
        # Get commits since last tag
        "$SCRIPT_DIR/generate-changelog.sh" -t "$PREV_TAG" -v "$VERSION" -d > "$TEMP_NOTES"
    else
        # First release - get all commits
        "$SCRIPT_DIR/generate-changelog.sh" -v "$VERSION" -d > "$TEMP_NOTES"
    fi
    
    # Extract just the version section
    awk '/^## \['"${VERSION//./\\.}"'\]/{flag=1;next}/^## \[/{flag=0}flag' "$TEMP_NOTES" > "$TEMP_NOTES.clean"
    mv "$TEMP_NOTES.clean" "$TEMP_NOTES"
    
    NOTES_FILE="$TEMP_NOTES"
fi

# Build the release command
RELEASE_CMD=(gh release create "$TAG")

# Add title
RELEASE_CMD+=(--title "$TITLE")

# Add notes
if [ -n "$NOTES_FILE" ] && [ -f "$NOTES_FILE" ]; then
    RELEASE_CMD+=(--notes-file "$NOTES_FILE")
elif [ "$GENERATE_NOTES" = true ]; then
    RELEASE_CMD+=(--generate-notes)
fi

# Add flags
if [ "$DRAFT" = true ]; then
    RELEASE_CMD+=(--draft)
fi

if [ "$PRERELEASE" = true ]; then
    RELEASE_CMD+=(--prerelease)
fi

# Add assets
for asset in "${ASSETS[@]}"; do
    if [ -f "$asset" ]; then
        RELEASE_CMD+=("$asset")
    else
        echo -e "${YELLOW}Warning: Asset not found: $asset${NC}"
    fi
done

# Create the tag
echo -e "${BLUE}Creating tag $TAG...${NC}"
git tag -a "$TAG" -m "Release $VERSION"

# Create the release
echo -e "${BLUE}Creating GitHub release...${NC}"
if "${RELEASE_CMD[@]}"; then
    echo -e "${GREEN}✓ Release created successfully!${NC}"
    
    # Show release URL
    RELEASE_URL="https://github.com/vibeprogrammer/Think-client/releases/tag/$TAG"
    echo ""
    echo "Release URL: $RELEASE_URL"
    
    # Clean up temporary files
    if [ -n "$TEMP_NOTES" ] && [ -f "$TEMP_NOTES" ]; then
        rm -f "$TEMP_NOTES"
    fi
    
    # Push the tag
    echo ""
    echo -e "${BLUE}Pushing tag to origin...${NC}"
    if git push origin "$TAG"; then
        echo -e "${GREEN}✓ Tag pushed successfully!${NC}"
    else
        echo -e "${YELLOW}Warning: Failed to push tag${NC}"
        echo "Push manually with: git push origin $TAG"
    fi
else
    echo -e "${RED}Error: Failed to create release${NC}" >&2
    
    # Clean up the tag
    git tag -d "$TAG"
    
    # Clean up temporary files
    if [ -n "$TEMP_NOTES" ] && [ -f "$TEMP_NOTES" ]; then
        rm -f "$TEMP_NOTES"
    fi
    
    exit 1
fi