#!/bin/bash

# Conventional Commits Version Bumper
# Automatically bumps version based on conventional commit messages
# Follows Semantic Versioning: MAJOR.MINOR.PATCH

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DRY_RUN=false
LAST_TAG=""
VERBOSE=false

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

# Source shared version functions
source "$SCRIPT_DIR/shared-version.sh"

# Function to show usage
show_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --dry-run           Show what would be done without making changes"
    echo "  --from-tag TAG      Analyze commits from this tag (default: latest tag)"
    echo "  --verbose           Show detailed commit analysis"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "This script analyzes git commits since the last version tag and"
    echo "automatically bumps the version according to conventional commits:"
    echo "  - feat: bumps MINOR version"
    echo "  - fix, chore, docs, etc: bumps PATCH version"
    echo "  - BREAKING CHANGE or !: bumps MAJOR version"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --from-tag)
            LAST_TAG="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
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

# Function to get the last version tag
get_last_version_tag() {
    if [ -n "$LAST_TAG" ]; then
        echo "$LAST_TAG"
    else
        # Get the most recent tag that looks like a version
        git tag -l --sort=-version:refname | grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+$' | head -n1
    fi
}

# Function to analyze commits since last tag
analyze_commits() {
    local from_ref="$1"
    local has_breaking=false
    local has_feat=false
    local has_fix=false
    local commit_count=0
    
    echo -e "${BLUE}Analyzing commits since ${from_ref}...${NC}" >&2
    
    # Get all commits since the reference
    local commits
    if [ -n "$from_ref" ]; then
        commits=$(git log "${from_ref}..HEAD" --format="%H %s" --no-merges)
    else
        commits=$(git log --format="%H %s" --no-merges)
    fi
    
    if [ -z "$commits" ]; then
        echo -e "${YELLOW}No commits found since last version${NC}" >&2
        return 1
    fi
    
    # Analyze each commit
    while IFS= read -r commit_line; do
        [ -z "$commit_line" ] && continue
        
        commit_count=$((commit_count + 1))
        local hash=$(echo "$commit_line" | cut -d' ' -f1)
        local subject=$(echo "$commit_line" | cut -d' ' -f2-)
        
        if [ "$VERBOSE" = true ]; then
            echo -e "  Checking: ${subject}" >&2
        fi
        
        # Check for breaking changes in subject (with !)
        if echo "$subject" | grep -qE '^[a-zA-Z]+(\([^)]+\))?!:'; then
            has_breaking=true
            if [ "$VERBOSE" = true ]; then
                echo -e "    ${RED}→ Breaking change (!) detected${NC}" >&2
            fi
        fi
        
        # Check for breaking changes in commit body
        local body=$(git log -1 --format="%B" "$hash")
        if echo "$body" | grep -qi "BREAKING CHANGE:"; then
            has_breaking=true
            if [ "$VERBOSE" = true ]; then
                echo -e "    ${RED}→ Breaking change (footer) detected${NC}" >&2
            fi
        fi
        
        # Check commit type
        if echo "$subject" | grep -qE '^feat(\([^)]+\))?!?:'; then
            has_feat=true
            if [ "$VERBOSE" = true ]; then
                echo -e "    ${GREEN}→ Feature detected${NC}" >&2
            fi
        elif echo "$subject" | grep -qE '^fix(\([^)]+\))?!?:'; then
            has_fix=true
            if [ "$VERBOSE" = true ]; then
                echo -e "    ${YELLOW}→ Fix detected${NC}" >&2
            fi
        elif echo "$subject" | grep -qE '^(chore|docs|style|refactor|perf|test|build|ci)(\([^)]+\))?!?:'; then
            has_fix=true  # Other types count as patch
            if [ "$VERBOSE" = true ]; then
                echo -e "    ${YELLOW}→ Patch change detected${NC}" >&2
            fi
        fi
    done <<< "$commits"
    
    echo -e "${BLUE}Analyzed ${commit_count} commits${NC}" >&2
    
    # Determine version bump type
    local bump_type
    if [ "$has_breaking" = true ]; then
        bump_type="major"
    elif [ "$has_feat" = true ]; then
        bump_type="minor"
    elif [ "$has_fix" = true ]; then
        bump_type="patch"
    else
        bump_type="none"
    fi
    
    echo "$bump_type"
}

# Main execution
main() {
    cd "$PROJECT_ROOT"
    
    # Get current version
    local current_version=$(get_marketing_version)
    echo -e "${BLUE}Current version: ${current_version}${NC}"
    
    # Get last version tag
    local last_tag=$(get_last_version_tag)
    if [ -z "$last_tag" ]; then
        echo -e "${YELLOW}No previous version tag found, analyzing all commits${NC}"
    else
        echo -e "${BLUE}Last version tag: ${last_tag}${NC}"
    fi
    
    # Analyze commits
    local bump_type=$(analyze_commits "$last_tag")
    
    if [ "$bump_type" = "none" ]; then
        echo -e "${YELLOW}No version bump needed based on conventional commits${NC}"
        exit 0
    fi
    
    echo -e "${GREEN}Version bump type: ${bump_type}${NC}"
    
    # Calculate new version
    local new_version
    case "$bump_type" in
        major)
            new_version=$(bump_version "$current_version" "major")
            ;;
        minor)
            new_version=$(bump_version "$current_version" "minor")
            ;;
        patch)
            new_version=$(bump_version "$current_version" "patch")
            ;;
    esac
    
    echo -e "${GREEN}New version will be: ${new_version}${NC}"
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}DRY RUN: No changes made${NC}"
        echo ""
        echo "Would have performed:"
        echo "  1. Set marketing version to ${new_version}"
        echo "  2. Increment build number"
        echo "  3. Record build environment"
        echo "  4. Commit version changes"
        echo "  5. Push changes with --no-verify"
        exit 0
    fi
    
    # Actually bump the version
    echo -e "${BLUE}Updating version...${NC}"
    
    # Set the new marketing version
    SILENT_MODE=true
    set_marketing_version "$new_version"
    
    # Increment build number
    increment_build_number
    
    # Get the new build number for commit message
    local new_build=$(get_build_number)
    
    echo -e "${GREEN}✓ Version updated to ${new_version} (${new_build})${NC}"
    
    # Record build environment
    echo -e "${BLUE}Recording build environment...${NC}"
    "$SCRIPT_DIR/record-environment.sh" record
    
    # Stage version changes
    echo -e "${BLUE}Staging version changes...${NC}"
    git add -A
    
    # Create commit message
    local commit_msg="chore(release): bump version to ${new_version} (${new_build})

Automated version bump based on conventional commits:
- Previous version: ${current_version}
- New version: ${new_version}
- Build number: ${new_build}
- Bump type: ${bump_type}"
    
    # Commit changes
    echo -e "${BLUE}Committing version changes...${NC}"
    git commit -m "$commit_msg" --no-verify
    
    # Push changes
    echo -e "${BLUE}Pushing changes...${NC}"
    git push --no-verify
    
    echo -e "${GREEN}✅ Version bump complete!${NC}"
    echo -e "${GREEN}   Version: ${new_version}${NC}"
    echo -e "${GREEN}   Build: ${new_build}${NC}"
}

# Run main function
main