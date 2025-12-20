#!/bin/bash
# Record build environment for reproducibility
# Creates .build_environment file with all relevant build information

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Output file
OUTPUT_FILE="$PROJECT_ROOT/.build_environment"

# Function to get Xcode version
get_xcode_version() {
    xcodebuild -version 2>/dev/null | head -n 1 || echo "Xcode: Unknown"
}

# Function to get Xcode build
get_xcode_build() {
    xcodebuild -version 2>/dev/null | tail -n 1 || echo "Build: Unknown"
}

# Function to get selected Xcode path
get_xcode_path() {
    xcode-select -p 2>/dev/null || echo "Unknown"
}

# Function to get macOS version
get_macos_version() {
    sw_vers -productVersion 2>/dev/null || echo "Unknown"
}

# Function to get hardware info
get_hardware_info() {
    sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Unknown"
}

# Function to get git info
get_git_info() {
    cd "$PROJECT_ROOT"
    
    local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "Unknown")
    local commit=$(git rev-parse HEAD 2>/dev/null || echo "Unknown")
    local short_commit=$(git rev-parse --short HEAD 2>/dev/null || echo "Unknown")
    local tag=$(git describe --tags --exact-match 2>/dev/null || echo "No tag")
    local dirty=""
    
    # Check if working directory is clean
    if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
        dirty=" (dirty)"
    fi
    
    echo "Branch: $branch"
    echo "Commit: $commit"
    echo "Short: $short_commit$dirty"
    echo "Tag: $tag"
}

# Function to get version info
get_version_info() {
    local marketing=$("$SCRIPT_DIR/shared-version.sh" get-marketing 2>/dev/null || echo "Unknown")
    local build=$("$SCRIPT_DIR/shared-version.sh" get-build 2>/dev/null || echo "Unknown")
    
    echo "Marketing: $marketing"
    echo "Build: $build"
}

# Function to format date
format_date() {
    date '+%Y-%m-%d %H:%M:%S %Z'
}

# Main function
record_environment() {
    echo -e "${BLUE}Recording build environment...${NC}"
    
    # Create the environment file
    cat > "$OUTPUT_FILE" << EOF
# Think Build Environment
# Generated: $(format_date)
# This file records the build environment for reproducibility

[Timestamp]
Date = $(date '+%Y-%m-%d')
Time = $(date '+%H:%M:%S')
Timezone = $(date '+%Z')
Unix = $(date '+%s')

[System]
macOS = $(get_macos_version)
Hardware = $(get_hardware_info)
Architecture = $(uname -m)

[Xcode]
Version = $(get_xcode_version | cut -d' ' -f2)
Build = $(get_xcode_build | cut -d' ' -f2)
Path = $(get_xcode_path)

[Git]
$(get_git_info)

[Version]
$(get_version_info)

[Swift]
Version = $(swift --version 2>/dev/null | head -n 1 | cut -d' ' -f4 || echo "Unknown")

[Environment]
USER = $USER
PWD = $PWD

[Build Configuration]
Configurations = Debug, Release
Platforms = iOS, macOS, visionOS
Architectures = arm64, x86_64

[Dependencies]
xcbeautify = $(xcbeautify --version 2>/dev/null || echo "Not installed")
jq = $(jq --version 2>/dev/null || echo "Not installed")
gh = $(gh --version 2>/dev/null | head -n 1 || echo "Not installed")
git-cliff = $(git-cliff --version 2>/dev/null || echo "Not installed")

[Notes]
# Add any additional notes about this build here
EOF
    
    echo -e "${GREEN}✓ Build environment recorded to: $OUTPUT_FILE${NC}"
    
    # Also create a JSON version for programmatic access
    local json_file="${OUTPUT_FILE}.json"
    
    cat > "$json_file" << EOF
{
  "timestamp": {
    "date": "$(date '+%Y-%m-%d')",
    "time": "$(date '+%H:%M:%S')",
    "timezone": "$(date '+%Z')",
    "unix": $(date '+%s')
  },
  "system": {
    "macos": "$(get_macos_version)",
    "hardware": "$(get_hardware_info)",
    "architecture": "$(uname -m)"
  },
  "xcode": {
    "version": "$(get_xcode_version | cut -d' ' -f2)",
    "build": "$(get_xcode_build | cut -d' ' -f2)",
    "path": "$(get_xcode_path)"
  },
  "git": {
    "branch": "$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "Unknown")",
    "commit": "$(git rev-parse HEAD 2>/dev/null || echo "Unknown")",
    "short": "$(git rev-parse --short HEAD 2>/dev/null || echo "Unknown")",
    "tag": "$(git describe --tags --exact-match 2>/dev/null || echo "null")",
    "clean": $(git diff --quiet 2>/dev/null && git diff --cached --quiet 2>/dev/null && echo "true" || echo "false")
  },
  "version": {
    "marketing": "$("$SCRIPT_DIR/shared-version.sh" get-marketing 2>/dev/null || echo "Unknown")",
    "build": "$("$SCRIPT_DIR/shared-version.sh" get-build 2>/dev/null || echo "Unknown")"
  },
  "swift": {
    "version": "$(swift --version 2>/dev/null | head -n 1 | cut -d' ' -f4 || echo "Unknown")"
  }
}
EOF
    
    echo -e "${GREEN}✓ JSON environment recorded to: $json_file${NC}"
}

# Function to display recorded environment
show_environment() {
    if [ ! -f "$OUTPUT_FILE" ]; then
        echo "No build environment recorded yet."
        echo "Run: $0 record"
        exit 1
    fi
    
    echo -e "${BLUE}Build Environment${NC}"
    echo "================="
    cat "$OUTPUT_FILE"
}

# Main command handler
case "${1:-record}" in
    record)
        record_environment
        ;;
    show)
        show_environment
        ;;
    *)
        echo "Build Environment Recorder"
        echo "========================="
        echo ""
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  record  Record current build environment (default)"
        echo "  show    Display recorded environment"
        echo ""
        echo "The environment is recorded to:"
        echo "  .build_environment (human-readable)"
        echo "  .build_environment.json (machine-readable)"
        exit 1
        ;;
esac
