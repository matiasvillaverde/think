#!/bin/bash
# Export signed app/IPA from Xcode archive
# Handles iOS, macOS, and visionOS platforms

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
ARCHIVE_PATH=""
EXPORT_PATH=""
PLATFORM=""
EXPORT_OPTIONS_PLIST=""

# Function to show usage
usage() {
    echo "Export Archive Script"
    echo "===================="
    echo ""
    echo "Usage: $0 -a <archive> -o <output> -p <platform> [-e <export-options>]"
    echo ""
    echo "Options:"
    echo "  -a <archive>        Path to .xcarchive"
    echo "  -o <output>         Output directory for exported app/IPA"
    echo "  -p <platform>       Platform: ios, macos, or visionos"
    echo "  -e <export-options> Path to ExportOptions.plist (optional)"
    echo "  -h                  Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -a build/archives/Think-iOS.xcarchive -o build/export -p ios"
    echo "  $0 -a build/archives/Think-macOS.xcarchive -o build/export -p macos"
    exit 1
}

# Parse command line arguments
while getopts "a:o:p:e:h" opt; do
    case $opt in
        a)
            ARCHIVE_PATH="$OPTARG"
            ;;
        o)
            EXPORT_PATH="$OPTARG"
            ;;
        p)
            PLATFORM="$OPTARG"
            ;;
        e)
            EXPORT_OPTIONS_PLIST="$OPTARG"
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

# Validate required arguments
if [ -z "$ARCHIVE_PATH" ] || [ -z "$EXPORT_PATH" ] || [ -z "$PLATFORM" ]; then
    echo -e "${RED}Error: Missing required arguments${NC}" >&2
    usage
fi

# Validate archive exists
if [ ! -d "$ARCHIVE_PATH" ]; then
    echo -e "${RED}Error: Archive not found: $ARCHIVE_PATH${NC}" >&2
    exit 1
fi

# Create default export options if not provided
if [ -z "$EXPORT_OPTIONS_PLIST" ]; then
    # Use existing ExportOptions.plist or create temporary one
    if [ -f "$PROJECT_ROOT/Think/ExportOptions.plist" ]; then
        EXPORT_OPTIONS_PLIST="$PROJECT_ROOT/Think/ExportOptions.plist"
    else
        # Create temporary export options
        EXPORT_OPTIONS_PLIST="$EXPORT_PATH/ExportOptions.plist"
        mkdir -p "$EXPORT_PATH"
        
        echo -e "${YELLOW}Creating temporary ExportOptions.plist...${NC}"
        
        # Load team ID from environment
        source "$SCRIPT_DIR/.env" 2>/dev/null || true
        TEAM_ID="${TEAM_ID:-${DEVELOPMENT_TEAM:-}}"
        if [ -z "$TEAM_ID" ]; then
            echo -e "${RED}Error: TEAM_ID not set${NC}" >&2
            exit 1
        fi
        
        cat > "$EXPORT_OPTIONS_PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>teamID</key>
    <string>$TEAM_ID</string>
    <key>uploadSymbols</key>
    <true/>
    <key>signingStyle</key>
    <string>automatic</string>
EOF
        
        # Add platform-specific options
        case "$PLATFORM" in
            ios)
                cat >> "$EXPORT_OPTIONS_PLIST" << EOF
    <key>compileBitcode</key>
    <false/>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>thinning</key>
    <string>&lt;none&gt;</string>
EOF
                ;;
            macos)
                cat >> "$EXPORT_OPTIONS_PLIST" << EOF
    <key>signingCertificate</key>
    <string>3rd Party Mac Developer Application</string>
    <key>installerSigningCertificate</key>
    <string>3rd Party Mac Developer Installer</string>
EOF
                ;;
            visionos)
                cat >> "$EXPORT_OPTIONS_PLIST" << EOF
    <key>compileBitcode</key>
    <false/>
    <key>stripSwiftSymbols</key>
    <true/>
EOF
                ;;
        esac
        
        cat >> "$EXPORT_OPTIONS_PLIST" << EOF
</dict>
</plist>
EOF
    fi
fi

# Create export directory
mkdir -p "$EXPORT_PATH"

# Export the archive
echo -e "${BLUE}Exporting $PLATFORM archive...${NC}"
echo "Archive: $ARCHIVE_PATH"
echo "Export to: $EXPORT_PATH"
echo "Options: $EXPORT_OPTIONS_PLIST"

# Perform the export
if xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
    -allowProvisioningUpdates \
    -quiet; then
    
    echo -e "${GREEN}✓ Export successful!${NC}"
    
    # List exported files
    echo ""
    echo "Exported files:"
    ls -la "$EXPORT_PATH"
    
    # Platform-specific post-processing
    case "$PLATFORM" in
        ios|visionos)
            # Find IPA file
            IPA_FILE=$(find "$EXPORT_PATH" -name "*.ipa" -type f | head -n 1)
            if [ -n "$IPA_FILE" ]; then
                echo ""
                echo -e "${GREEN}IPA created: $IPA_FILE${NC}"
                
                # Show IPA info
                IPA_SIZE=$(du -h "$IPA_FILE" | cut -f1)
                echo "Size: $IPA_SIZE"
                
                # Extract and show app info
                TEMP_DIR=$(mktemp -d)
                unzip -q "$IPA_FILE" -d "$TEMP_DIR"
                APP_PATH=$(find "$TEMP_DIR" -name "*.app" -type d | head -n 1)
                if [ -n "$APP_PATH" ]; then
                    BUNDLE_ID=$(plutil -extract CFBundleIdentifier raw "$APP_PATH/Info.plist" 2>/dev/null || echo "Unknown")
                    VERSION=$(plutil -extract CFBundleShortVersionString raw "$APP_PATH/Info.plist" 2>/dev/null || echo "Unknown")
                    BUILD=$(plutil -extract CFBundleVersion raw "$APP_PATH/Info.plist" 2>/dev/null || echo "Unknown")
                    
                    echo "Bundle ID: $BUNDLE_ID"
                    echo "Version: $VERSION ($BUILD)"
                fi
                rm -rf "$TEMP_DIR"
            fi
            ;;
        macos)
            # Find app
            APP_FILE=$(find "$EXPORT_PATH" -name "*.app" -type d | head -n 1)
            if [ -n "$APP_FILE" ]; then
                echo ""
                echo -e "${GREEN}App exported: $APP_FILE${NC}"
                
                # Show app info
                APP_SIZE=$(du -sh "$APP_FILE" | cut -f1)
                echo "Size: $APP_SIZE"
                
                BUNDLE_ID=$(plutil -extract CFBundleIdentifier raw "$APP_FILE/Contents/Info.plist" 2>/dev/null || echo "Unknown")
                VERSION=$(plutil -extract CFBundleShortVersionString raw "$APP_FILE/Contents/Info.plist" 2>/dev/null || echo "Unknown")
                BUILD=$(plutil -extract CFBundleVersion raw "$APP_FILE/Contents/Info.plist" 2>/dev/null || echo "Unknown")
                
                echo "Bundle ID: $BUNDLE_ID"
                echo "Version: $VERSION ($BUILD)"
            fi
            ;;
    esac
    
else
    echo -e "${RED}❌ Export failed${NC}" >&2
    
    # Check common issues
    echo ""
    echo "Troubleshooting:"
    echo "1. Ensure you're signed in to Xcode with the correct Apple ID"
    echo "2. Check that automatic signing is configured for the project"
    echo "3. Verify the team ID in ExportOptions.plist matches your team"
    echo "4. Make sure you have the necessary provisioning profiles"
    
    exit 1
fi
