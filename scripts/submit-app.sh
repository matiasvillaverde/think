#!/bin/bash
# Submit app to App Store Connect using iTMSTransporter
# Replaces deprecated altool with modern iTMSTransporter

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
PLATFORM="ios"
ARCHIVE_PATH=""
APP_ID=""
VERSION=""
BUILD=""
SUBMIT_FOR_REVIEW=false
WAIT_FOR_PROCESSING=true

# Function to show usage
usage() {
    echo "App Store Submission Tool (iTMSTransporter)"
    echo "==========================================="
    echo ""
    echo "Usage: $0 -a <archive> [options]"
    echo ""
    echo "Required:"
    echo "  -a, --archive <path>     Path to .xcarchive"
    echo ""
    echo "Options:"
    echo "  -p, --platform <platform>  Platform (ios, macos, visionos) [default: ios]"
    echo "  -i, --app-id <id>         App Store Connect app ID (auto-detected if not provided)"
    echo "  -v, --version <version>   Version string (auto-detected from archive)"
    echo "  -b, --build <build>       Build number (auto-detected from archive)"
    echo "  -r, --review              Submit for review after upload"
    echo "  --no-wait                 Don't wait for processing to complete"
    echo "  -h, --help                Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -a build/archives/Think-iOS.xcarchive"
    echo "  $0 -a build/archives/Think-macOS.xcarchive -p macos -r"
    echo ""
    echo "Note: Requires App Store Connect API credentials in .env"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--archive)
            ARCHIVE_PATH="$2"
            shift 2
            ;;
        -p|--platform)
            PLATFORM="$2"
            shift 2
            ;;
        -i|--app-id)
            APP_ID="$2"
            shift 2
            ;;
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -b|--build)
            BUILD="$2"
            shift 2
            ;;
        -r|--review)
            SUBMIT_FOR_REVIEW=true
            shift
            ;;
        --no-wait)
            WAIT_FOR_PROCESSING=false
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
if [ -z "$ARCHIVE_PATH" ]; then
    echo -e "${RED}Error: Archive path is required${NC}" >&2
    usage
fi

if [ ! -d "$ARCHIVE_PATH" ]; then
    echo -e "${RED}Error: Archive not found: $ARCHIVE_PATH${NC}" >&2
    exit 1
fi

# Load environment variables
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
fi

# Check required environment variables
if [ -z "$APPSTORE_KEY_ID" ] || [ -z "$APPSTORE_ISSUER_ID" ]; then
    echo -e "${RED}Error: Missing App Store Connect credentials${NC}" >&2
    echo "Please set APPSTORE_KEY_ID and APPSTORE_ISSUER_ID in scripts/.env" >&2
    exit 1
fi

# Check for TEAM_ID which is required for iTMSTransporter
if [ -z "$TEAM_ID" ]; then
    echo -e "${RED}Error: TEAM_ID not set${NC}" >&2
    echo "Please set TEAM_ID in scripts/.env" >&2
    exit 1
fi

# Extract version and build from archive if not provided
if [ -z "$VERSION" ] || [ -z "$BUILD" ]; then
    echo -e "${BLUE}Extracting version info from archive...${NC}"
    
    INFO_PLIST="$ARCHIVE_PATH/Info.plist"
    if [ ! -f "$INFO_PLIST" ]; then
        echo -e "${RED}Error: Info.plist not found in archive${NC}" >&2
        exit 1
    fi
    
    if [ -z "$VERSION" ]; then
        VERSION=$(plutil -extract ApplicationProperties.CFBundleShortVersionString raw -o - "$INFO_PLIST" 2>/dev/null || echo "")
        if [ -z "$VERSION" ]; then
            echo -e "${RED}Error: Could not extract version from archive${NC}" >&2
            exit 1
        fi
    fi
    
    if [ -z "$BUILD" ]; then
        BUILD=$(plutil -extract ApplicationProperties.CFBundleVersion raw -o - "$INFO_PLIST" 2>/dev/null || echo "")
        if [ -z "$BUILD" ]; then
            echo -e "${RED}Error: Could not extract build number from archive${NC}" >&2
            exit 1
        fi
    fi
fi

echo "Version: $VERSION"
echo "Build: $BUILD"

# Get app ID if not provided
if [ -z "$APP_ID" ]; then
    echo -e "${BLUE}Getting app ID...${NC}"
    
    # Extract bundle ID from archive
    BUNDLE_ID=$(plutil -extract ApplicationProperties.CFBundleIdentifier raw -o - "$ARCHIVE_PATH/Info.plist" 2>/dev/null || echo "")
    if [ -z "$BUNDLE_ID" ]; then
        echo -e "${RED}Error: Could not extract bundle ID from archive${NC}" >&2
        exit 1
    fi
    
    echo "Bundle ID: $BUNDLE_ID"
    
    # Get app ID from API
    APP_ID=$("$SCRIPT_DIR/get-app-id.sh" "$BUNDLE_ID")
    if [ -z "$APP_ID" ] || [ "$APP_ID" = "null" ]; then
        echo -e "${RED}Error: Could not find app with bundle ID: $BUNDLE_ID${NC}" >&2
        exit 1
    fi
fi

echo "App ID: $APP_ID"

# Map platform to API platform name
case "$PLATFORM" in
    ios)
        API_PLATFORM="IOS"
        ;;
    macos)
        API_PLATFORM="MAC_OS"
        ;;
    visionos)
        API_PLATFORM="VISION_OS"
        ;;
    *)
        echo -e "${RED}Error: Invalid platform: $PLATFORM${NC}" >&2
        exit 1
        ;;
esac

# Export the archive to IPA/PKG
echo ""
echo -e "${BLUE}Exporting archive...${NC}"
EXPORT_DIR="$PROJECT_ROOT/build/export/submission"
mkdir -p "$EXPORT_DIR"

"$SCRIPT_DIR/export-archive.sh" \
    -a "$ARCHIVE_PATH" \
    -o "$EXPORT_DIR" \
    -p "$PLATFORM"

# Find the exported file
if [ "$PLATFORM" = "ios" ] || [ "$PLATFORM" = "visionos" ]; then
    EXPORT_FILE=$(find "$EXPORT_DIR" -name "*.ipa" | head -n 1)
else
    EXPORT_FILE=$(find "$EXPORT_DIR" -name "*.pkg" | head -n 1)
fi

if [ -z "$EXPORT_FILE" ] || [ ! -f "$EXPORT_FILE" ]; then
    echo -e "${RED}Error: Export failed - no output file found${NC}" >&2
    exit 1
fi

echo "Exported to: $EXPORT_FILE"

# Get authentication key path
KEY_FILE=""
if [ -n "$APPSTORE_P8_KEY" ]; then
    # Create temporary key file
    KEY_FILE=$(mktemp)
    echo "$APPSTORE_P8_KEY" > "$KEY_FILE"
elif [ -n "$APP_STORE_CONNECT_API_KEY_PATH" ]; then
    KEY_FILE="$APP_STORE_CONNECT_API_KEY_PATH"
else
    # Look for key file
    KEY_FILE=$(find "$SCRIPT_DIR" -name "AuthKey_*.p8" -type f | head -n 1)
fi

if [ -z "$KEY_FILE" ] || [ ! -f "$KEY_FILE" ]; then
    echo -e "${RED}Error: No API key found${NC}" >&2
    exit 1
fi

# Create a temporary .itmsp package for iTMSTransporter
echo ""
echo -e "${BLUE}Preparing package for upload...${NC}"
PACKAGE_NAME="$(basename "$EXPORT_FILE" | sed 's/\.[^.]*$//')"
PACKAGE_DIR="$EXPORT_DIR/${PACKAGE_NAME}.itmsp"
mkdir -p "$PACKAGE_DIR"

# Copy the IPA/PKG into the .itmsp directory
cp "$EXPORT_FILE" "$PACKAGE_DIR/"

# Upload using iTMSTransporter with API key authentication
echo ""
echo -e "${BLUE}Uploading to App Store Connect using iTMSTransporter...${NC}"
echo "Package: $PACKAGE_DIR"

# Generate JWT token for authentication
JWT_TOKEN=$(python3 "$SCRIPT_DIR/generate_jwt.py" "$APPSTORE_KEY_ID" "$APPSTORE_ISSUER_ID" "$KEY_FILE" 2>/dev/null)

if [ -z "$JWT_TOKEN" ]; then
    echo -e "${RED}Error: Failed to generate JWT token${NC}" >&2
    # Clean up temporary key file
    if [ -n "$APPSTORE_P8_KEY" ] && [ -f "$KEY_FILE" ]; then
        rm -f "$KEY_FILE"
    fi
    exit 1
fi

# Upload with iTMSTransporter using JWT authentication
echo "Using JWT authentication..."
if xcrun iTMSTransporter \
    -m upload \
    -jwt "$JWT_TOKEN" \
    -v informational \
    -f "$PACKAGE_DIR" \
    -k 100000; then
    echo -e "${GREEN}✓ Upload successful!${NC}"
else
    echo -e "${RED}Error: Upload failed${NC}" >&2
    
    # Clean up temporary key file
    if [ -n "$APPSTORE_P8_KEY" ] && [ -f "$KEY_FILE" ]; then
        rm -f "$KEY_FILE"
    fi
    
    # Clean up package directory
    rm -rf "$PACKAGE_DIR"
    
    exit 1
fi

# Clean up
if [ -n "$APPSTORE_P8_KEY" ] && [ -f "$KEY_FILE" ]; then
    rm -f "$KEY_FILE"
fi
rm -rf "$PACKAGE_DIR"

# Wait for processing if requested
if [ "$WAIT_FOR_PROCESSING" = true ]; then
    echo ""
    echo -e "${BLUE}Waiting for build processing...${NC}"
    echo "This may take 5-30 minutes..."
    
    # Poll for build status
    POLL_INTERVAL=30
    MAX_ATTEMPTS=60  # 30 minutes
    ATTEMPTS=0
    
    while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
        sleep $POLL_INTERVAL
        ATTEMPTS=$((ATTEMPTS + 1))
        
        echo -n "."
        
        # Check if build is available
        BUILD_RESPONSE=$("$SCRIPT_DIR/appstore-api.sh" raw GET "/apps/$APP_ID/builds?filter[version]=$BUILD&filter[platform]=$API_PLATFORM&limit=1" 2>/dev/null || echo "")
        
        if [ -n "$BUILD_RESPONSE" ]; then
            BUILD_ID=$(echo "$BUILD_RESPONSE" | jq -r '.data[0].id' 2>/dev/null || echo "")
            if [ -n "$BUILD_ID" ] && [ "$BUILD_ID" != "null" ]; then
                BUILD_STATE=$(echo "$BUILD_RESPONSE" | jq -r '.data[0].attributes.processingState' 2>/dev/null || echo "")
                
                if [ "$BUILD_STATE" = "VALID" ]; then
                    echo ""
                    echo -e "${GREEN}✓ Build processed successfully!${NC}"
                    echo "Build ID: $BUILD_ID"
                    break
                elif [ "$BUILD_STATE" = "INVALID" ] || [ "$BUILD_STATE" = "FAILED" ]; then
                    echo ""
                    echo -e "${RED}Error: Build processing failed (state: $BUILD_STATE)${NC}" >&2
                    exit 1
                fi
            fi
        fi
    done
    
    if [ $ATTEMPTS -ge $MAX_ATTEMPTS ]; then
        echo ""
        echo -e "${YELLOW}Warning: Timeout waiting for build processing${NC}"
        echo "Check App Store Connect for build status"
    fi
fi

# Create or update app store version
echo ""
echo -e "${BLUE}Creating app store version...${NC}"

# Check if version already exists
VERSION_RESPONSE=$("$SCRIPT_DIR/appstore-api.sh" raw GET "/apps/$APP_ID/appStoreVersions?filter[versionString]=$VERSION&filter[platform]=$API_PLATFORM" 2>/dev/null || echo "")
VERSION_ID=$(echo "$VERSION_RESPONSE" | jq -r '.data[0].id' 2>/dev/null || echo "")

if [ -z "$VERSION_ID" ] || [ "$VERSION_ID" = "null" ]; then
    # Create new version
    echo "Creating version $VERSION..."
    CREATE_RESPONSE=$("$SCRIPT_DIR/appstore-api.sh" create-version "$APP_ID" "$VERSION" "$API_PLATFORM")
    VERSION_ID=$(echo "$CREATE_RESPONSE" | jq -r '.data.id' 2>/dev/null || echo "")
    
    if [ -z "$VERSION_ID" ] || [ "$VERSION_ID" = "null" ]; then
        echo -e "${RED}Error: Failed to create version${NC}" >&2
        exit 1
    fi
    
    echo -e "${GREEN}✓ Version created${NC}"
else
    echo "Version $VERSION already exists"
fi

echo "Version ID: $VERSION_ID"

# Associate build with version if we have the build ID
if [ -n "$BUILD_ID" ] && [ "$BUILD_ID" != "null" ]; then
    echo ""
    echo -e "${BLUE}Associating build with version...${NC}"
    
    if "$SCRIPT_DIR/appstore-api.sh" upload-build "$VERSION_ID" "$BUILD_ID" >/dev/null; then
        echo -e "${GREEN}✓ Build associated${NC}"
    else
        echo -e "${YELLOW}Warning: Failed to associate build${NC}"
        echo "You may need to do this manually in App Store Connect"
    fi
fi

# Submit for review if requested
if [ "$SUBMIT_FOR_REVIEW" = true ]; then
    echo ""
    echo -e "${BLUE}Submitting for review...${NC}"
    
    if "$SCRIPT_DIR/appstore-api.sh" submit-for-review "$VERSION_ID" >/dev/null; then
        echo -e "${GREEN}✓ Submitted for review!${NC}"
    else
        echo -e "${RED}Error: Failed to submit for review${NC}" >&2
        echo "Please complete submission manually in App Store Connect"
    fi
fi

# Summary
echo ""
echo -e "${GREEN}✨ Submission complete!${NC}"
echo ""
echo "Summary:"
echo "  Platform: $PLATFORM"
echo "  Version: $VERSION"
echo "  Build: $BUILD"
echo "  App ID: $APP_ID"
if [ -n "$VERSION_ID" ]; then
    echo "  Version ID: $VERSION_ID"
fi
if [ -n "$BUILD_ID" ] && [ "$BUILD_ID" != "null" ]; then
    echo "  Build ID: $BUILD_ID"
fi
echo ""
echo "Next steps:"
if [ "$SUBMIT_FOR_REVIEW" = false ]; then
    echo "  1. Go to App Store Connect"
    echo "  2. Complete app metadata"
    echo "  3. Submit for review"
else
    echo "  1. Monitor review status in App Store Connect"
    echo "  2. Respond to any reviewer feedback"
fi