#!/bin/bash
# Get version information for Think
# Simple wrapper around shared-version.sh for CI/CD integration

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default format
FORMAT="full"

# Function to show usage
usage() {
    echo "Get Version Script"
    echo "================="
    echo ""
    echo "Usage: $0 [-f format]"
    echo ""
    echo "Formats:"
    echo "  full       Full version string (2.0.5-50) [default]"
    echo "  marketing  Marketing version only (2.0.5)"
    echo "  build      Build number only (50)"
    echo "  json       JSON format with all details"
    echo "  tag        Git tag format (v2.0.5)"
    echo ""
    echo "Examples:"
    echo "  $0                  # Output: 2.0.5-50"
    echo "  $0 -f marketing     # Output: 2.0.5"
    echo "  $0 -f build         # Output: 50"
    echo "  $0 -f json          # Output: {\"marketing\":\"2.0.5\",\"build\":\"50\"}"
    echo "  $0 -f tag           # Output: v2.0.5"
    exit 1
}

# Parse command line arguments
while getopts "f:h" opt; do
    case $opt in
        f)
            FORMAT="$OPTARG"
            ;;
        h)
            usage
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            usage
            ;;
    esac
done

# Get version components
MARKETING=$("$SCRIPT_DIR/shared-version.sh" get-marketing)
BUILD=$("$SCRIPT_DIR/shared-version.sh" get-build)

# Output based on format
case "$FORMAT" in
    full)
        echo "${MARKETING}-${BUILD}"
        ;;
    marketing)
        echo "$MARKETING"
        ;;
    build)
        echo "$BUILD"
        ;;
    json)
        echo "{\"marketing\":\"$MARKETING\",\"build\":\"$BUILD\",\"full\":\"${MARKETING}-${BUILD}\"}"
        ;;
    tag)
        echo "v$MARKETING"
        ;;
    *)
        echo "Error: Unknown format: $FORMAT" >&2
        usage
        ;;
esac