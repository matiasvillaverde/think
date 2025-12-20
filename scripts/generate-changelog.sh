#!/bin/bash
# Generate changelog using git-cliff
# Supports both full and incremental changelog generation

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

# Default configuration
CONFIG_FILE="$PROJECT_ROOT/.git-cliff.toml"
OUTPUT_FILE="$PROJECT_ROOT/CHANGELOG.md"
VERSION=""
UNRELEASED=false
TAG=""
DRY_RUN=false

# Function to show usage
usage() {
    echo "Changelog Generator"
    echo "==================="
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -v, --version <version>   Generate changelog for specific version"
    echo "  -t, --tag <tag>          Generate changelog since specific tag"
    echo "  -u, --unreleased         Include unreleased changes"
    echo "  -o, --output <file>      Output file (default: CHANGELOG.md)"
    echo "  -c, --config <file>      Config file (default: .git-cliff.toml)"
    echo "  -d, --dry-run            Print changelog without writing to file"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                       Generate full changelog"
    echo "  $0 -v 2.0.6              Generate changelog for version 2.0.6"
    echo "  $0 -t v2.0.5             Generate changelog since tag v2.0.5"
    echo "  $0 -u                    Include unreleased changes"
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
        -u|--unreleased)
            UNRELEASED=true
            shift
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
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

# Check if git-cliff is installed
if ! command -v git-cliff &> /dev/null; then
    echo -e "${RED}Error: git-cliff is not installed${NC}" >&2
    echo "Install with: brew install git-cliff" >&2
    exit 1
fi

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}Error: Not in a git repository${NC}" >&2
    exit 1
fi

# Create default configuration if it doesn't exist
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${YELLOW}Creating default git-cliff configuration...${NC}"
    cat > "$CONFIG_FILE" << 'EOF'
# git-cliff configuration for Think

[changelog]
# Template for the changelog header
header = """
# Changelog

All notable changes to Think will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

"""
# Template for the changelog body
body = """
{% if version %}\
    ## [{{ version | trim_start_matches(pat="v") }}] - {{ timestamp | date(format="%Y-%m-%d") }}
{% else %}\
    ## [Unreleased]
{% endif %}\
{% for group, commits in commits | group_by(attribute="group") %}
    ### {{ group | upper_first }}
    {% for commit in commits %}
        - {{ commit.message | upper_first }}{% if commit.breaking %} **BREAKING**{% endif %}\
    {% endfor %}
{% endfor %}\n
"""
# Remove the leading and trailing whitespace
trim = true
# Changelog footer
footer = """
<!-- Think - AI for Apple Platforms -->
"""

[git]
# Parse the commits based on conventional commits
conventional_commits = true
# Filter out the commits that are not conventional
filter_unconventional = false
# Process each line of a commit as an individual commit
split_commits = false
# Regex for preprocessing the commit messages
commit_preprocessors = [
    { pattern = '\((\w+\s)?#([0-9]+)\)', replace = "([#${2}](https://github.com/vibeprogrammer/Think-client/issues/${2}))" },
    { pattern = 'Merge pull request #([0-9]+) from .+', replace = "Merge PR [#${1}](https://github.com/vibeprogrammer/Think-client/pull/${1})" },
]
# Regex for parsing and grouping commits
commit_parsers = [
    { message = "^feat", group = "Features" },
    { message = "^fix", group = "Bug Fixes" },
    { message = "^doc", group = "Documentation" },
    { message = "^perf", group = "Performance" },
    { message = "^refactor", group = "Refactoring" },
    { message = "^style", group = "Styling" },
    { message = "^test", group = "Testing" },
    { message = "^chore\\(release\\): prepare for", skip = true },
    { message = "^chore", group = "Miscellaneous Tasks" },
    { body = ".*security", group = "Security" },
]
# Protect breaking changes from being skipped
protect_breaking_commits = true
# Filter out the commits that are not matched by commit parsers
filter_commits = false
# Sort the tags topologically
topo_order = false
# Sort the commits inside sections by oldest/newest order
sort_commits = "oldest"
EOF
    echo -e "${GREEN}✓ Created default configuration${NC}"
fi

# Build git-cliff command
CLIFF_CMD=(git-cliff)

# Add configuration file
CLIFF_CMD+=(--config "$CONFIG_FILE")

# Add version or tag options
if [ -n "$VERSION" ]; then
    CLIFF_CMD+=(--tag "v$VERSION")
elif [ -n "$TAG" ]; then
    CLIFF_CMD+=(--tag "$TAG")
fi

# Add unreleased option
if [ "$UNRELEASED" = true ]; then
    CLIFF_CMD+=(--unreleased)
fi

# Generate changelog
echo -e "${BLUE}Generating changelog...${NC}"

if [ "$DRY_RUN" = true ]; then
    # Dry run - print to stdout
    "${CLIFF_CMD[@]}"
else
    # Generate to file
    if "${CLIFF_CMD[@]}" > "$OUTPUT_FILE.tmp"; then
        mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"
        echo -e "${GREEN}✓ Changelog generated successfully!${NC}"
        echo "Output: $OUTPUT_FILE"
        
        # Show recent changes
        echo ""
        echo "Recent changes:"
        echo "==============="
        head -n 20 "$OUTPUT_FILE" | tail -n 15
    else
        echo -e "${RED}Error: Failed to generate changelog${NC}" >&2
        rm -f "$OUTPUT_FILE.tmp"
        exit 1
    fi
fi