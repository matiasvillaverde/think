#!/bin/bash
# App Store Connect API wrapper
# Handles JWT token generation and API calls

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# API base URL
API_BASE="https://api.appstoreconnect.apple.com/v1"

# Load environment variables
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
fi

DEFAULT_BUNDLE_ID="${APPSTORE_BUNDLE_ID:-com.example.app}"

# Check required variables
if [ -z "$APPSTORE_KEY_ID" ] || [ -z "$APPSTORE_ISSUER_ID" ]; then
    echo -e "${RED}Error: Missing required environment variables${NC}" >&2
    echo "Please set APPSTORE_KEY_ID and APPSTORE_ISSUER_ID in .env" >&2
    exit 1
fi

# Function to get the private key content
get_private_key() {
    # Check if we have the key content directly
    if [ -n "$APPSTORE_P8_KEY" ]; then
        echo "$APPSTORE_P8_KEY"
        return 0
    fi
    
    # Check for key file path
    if [ -n "$APP_STORE_CONNECT_API_KEY_PATH" ] && [ -f "$APP_STORE_CONNECT_API_KEY_PATH" ]; then
        cat "$APP_STORE_CONNECT_API_KEY_PATH"
        return 0
    fi
    
    # Look for key file in scripts directory
    local key_file=$(find "$SCRIPT_DIR" -name "AuthKey_*.p8" -type f | head -n 1)
    if [ -n "$key_file" ] && [ -f "$key_file" ]; then
        cat "$key_file"
        return 0
    fi
    
    echo -e "${RED}Error: No private key found${NC}" >&2
    echo "Please provide APPSTORE_P8_KEY or APP_STORE_CONNECT_API_KEY_PATH in .env" >&2
    return 1
}

# Function to generate JWT token using Python
generate_jwt() {
    # Use Python script for JWT generation
    local script_dir="$(dirname "$0")"
    local jwt_token=$(python3 "$script_dir/generate_jwt.py" "$APPSTORE_KEY_ID" "$APPSTORE_ISSUER_ID" "$APP_STORE_CONNECT_API_KEY_PATH" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$jwt_token" ]; then
        echo "$jwt_token"
        return 0
    else
        echo -e "${RED}Error: Failed to generate JWT token${NC}" >&2
        return 1
    fi
}

# Function to make API request
api_request() {
    local method="$1"
    local endpoint="$2"
    local data="$3"
    
    # Generate JWT token
    local jwt=$(generate_jwt)
    if [ -z "$jwt" ]; then
        return 1
    fi
    
    # Build curl command
    local curl_cmd=(curl -s)
    curl_cmd+=(-X "$method")
    curl_cmd+=(-H "Authorization: Bearer $jwt")
    curl_cmd+=(-H "Content-Type: application/json")
    
    # Add data if provided
    if [ -n "$data" ]; then
        curl_cmd+=(-d "$data")
    fi
    
    # Add URL
    curl_cmd+=("$API_BASE$endpoint")
    
    # Execute request
    local response=$("${curl_cmd[@]}" 2>&1)
    local exit_code=$?
    
    # Check for errors
    if [ $exit_code -ne 0 ]; then
        echo -e "${RED}Error: API request failed${NC}" >&2
        echo "$response" >&2
        return 1
    fi
    
    # Check if response is JSON error
    if echo "$response" | jq -e '.errors' >/dev/null 2>&1; then
        echo -e "${RED}API Error:${NC}" >&2
        echo "$response" | jq '.errors' >&2
        return 1
    fi
    
    # Return response
    echo "$response"
}

# Function to get app info
get_app_info() {
    local bundle_id="${1:-$DEFAULT_BUNDLE_ID}"
    
    echo -e "${BLUE}Getting app info for: $bundle_id${NC}" >&2
    
    local response=$(api_request GET "/apps?filter[bundleId]=$bundle_id")
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    # Extract app data
    echo "$response" | jq -r '.data[0]'
}

# Function to get app ID
get_app_id() {
    local bundle_id="${1:-$DEFAULT_BUNDLE_ID}"
    
    local app_info=$(get_app_info "$bundle_id")
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    echo "$app_info" | jq -r '.id'
}

# Function to list app versions
list_app_versions() {
    local app_id="$1"
    
    if [ -z "$app_id" ]; then
        app_id=$(get_app_id)
        if [ $? -ne 0 ]; then
            return 1
        fi
    fi
    
    echo -e "${BLUE}Listing app versions...${NC}" >&2
    
    api_request GET "/apps/$app_id/appStoreVersions"
}

# Function to create new version
create_app_version() {
    local app_id="$1"
    local version="$2"
    local platform="${3:-IOS}"
    
    if [ -z "$app_id" ] || [ -z "$version" ]; then
        echo -e "${RED}Error: App ID and version required${NC}" >&2
        return 1
    fi
    
    echo -e "${BLUE}Creating version $version for platform $platform...${NC}" >&2
    
    local data=$(cat <<EOF
{
    "data": {
        "type": "appStoreVersions",
        "attributes": {
            "platform": "$platform",
            "versionString": "$version"
        },
        "relationships": {
            "app": {
                "data": {
                    "type": "apps",
                    "id": "$app_id"
                }
            }
        }
    }
}
EOF
)
    
    api_request POST "/appStoreVersions" "$data"
}

# Function to upload build
upload_build() {
    local version_id="$1"
    local build_id="$2"
    
    if [ -z "$version_id" ] || [ -z "$build_id" ]; then
        echo -e "${RED}Error: Version ID and build ID required${NC}" >&2
        return 1
    fi
    
    echo -e "${BLUE}Associating build $build_id with version $version_id...${NC}" >&2
    
    local data=$(cat <<EOF
{
    "data": {
        "type": "appStoreVersions",
        "id": "$version_id",
        "relationships": {
            "build": {
                "data": {
                    "type": "builds",
                    "id": "$build_id"
                }
            }
        }
    }
}
EOF
)
    
    api_request PATCH "/appStoreVersions/$version_id" "$data"
}

# Function to submit for review
submit_for_review() {
    local version_id="$1"
    
    if [ -z "$version_id" ]; then
        echo -e "${RED}Error: Version ID required${NC}" >&2
        return 1
    fi
    
    echo -e "${BLUE}Submitting version $version_id for review...${NC}" >&2
    
    local data=$(cat <<EOF
{
    "data": {
        "type": "appStoreVersionSubmissions",
        "relationships": {
            "appStoreVersion": {
                "data": {
                    "type": "appStoreVersions",
                    "id": "$version_id"
                }
            }
        }
    }
}
EOF
)
    
    api_request POST "/appStoreVersionSubmissions" "$data"
}

# Main command handler
case "${1:-help}" in
    test)
        echo -e "${BLUE}Testing App Store Connect API connection...${NC}"
        if api_request GET "/apps?limit=1" >/dev/null; then
            echo -e "${GREEN}✓ API connection successful!${NC}"
        else
            echo -e "${RED}✗ API connection failed${NC}"
            exit 1
        fi
        ;;
        
    get-app)
        get_app_info "${2:-$DEFAULT_BUNDLE_ID}" | jq .
        ;;
        
    list-versions)
        list_app_versions "$2" | jq .
        ;;
        
    create-version)
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "Usage: $0 create-version <app-id> <version> [platform]"
            exit 1
        fi
        create_app_version "$2" "$3" "${4:-IOS}" | jq .
        ;;
        
    raw)
        # Raw API request
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "Usage: $0 raw <method> <endpoint> [data]"
            exit 1
        fi
        api_request "$2" "$3" "$4" | jq .
        ;;
        
    *)
        echo "App Store Connect API Wrapper"
        echo "============================"
        echo ""
        echo "Usage: $0 <command> [args]"
        echo ""
        echo "Commands:"
        echo "  test                     Test API connection"
        echo "  get-app [bundle-id]      Get app information"
        echo "  list-versions [app-id]   List app store versions"
        echo "  create-version <app-id> <version> [platform]"
        echo "                          Create new app version"
        echo "  raw <method> <endpoint> [data]"
        echo "                          Make raw API request"
        echo ""
        echo "Environment variables required:"
        echo "  APPSTORE_KEY_ID         API Key ID"
        echo "  APPSTORE_ISSUER_ID      Issuer ID"
        echo "  APPSTORE_P8_KEY         Private key content (or use file)"
        echo "  APPSTORE_BUNDLE_ID      Default bundle ID (optional)"
        echo ""
        echo "Examples:"
        echo "  $0 test"
        echo "  $0 get-app $DEFAULT_BUNDLE_ID"
        echo "  $0 list-versions \$APP_ID"
        echo "  $0 create-version \$APP_ID 2.0.6"
        exit 1
        ;;
esac
