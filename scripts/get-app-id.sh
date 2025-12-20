#!/bin/bash
# Get App Store Connect app ID from bundle identifier

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source environment variables if available
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
fi

# Default bundle ID
DEFAULT_BUNDLE_ID="${APPSTORE_BUNDLE_ID:-com.example.app}"
BUNDLE_ID="${1:-$DEFAULT_BUNDLE_ID}"

# Optional override when API access isn't available
if [ -z "$1" ] && [ -n "$APPSTORE_APP_ID" ]; then
    echo "$APPSTORE_APP_ID"
    exit 0
fi

# Get app ID using the API wrapper
"$SCRIPT_DIR/appstore-api.sh" get-app "$BUNDLE_ID" | jq -r '.id'
