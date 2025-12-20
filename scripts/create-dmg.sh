#!/bin/bash
# Create DMG installer for macOS app
# Creates a beautiful DMG with background image and custom layout

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
APP_PATH=""
OUTPUT_PATH=""
VOLUME_NAME="Think"
DMG_NAME=""
BACKGROUND_IMAGE=""

# Function to show usage
usage() {
    echo "Create DMG Script"
    echo "================"
    echo ""
    echo "Usage: $0 -a <app> -o <output> [-n <name>] [-v <volume>] [-b <background>]"
    echo ""
    echo "Options:"
    echo "  -a <app>         Path to .app bundle"
    echo "  -o <output>      Output directory for DMG"
    echo "  -n <name>        DMG filename (without .dmg extension)"
    echo "  -v <volume>      Volume name (default: Think)"
    echo "  -b <background>  Path to background image (optional)"
    echo "  -h               Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 -a build/export/Think.app -o build/dmg -n Think-2.0.5"
    exit 1
}

# Parse command line arguments
while getopts "a:o:n:v:b:h" opt; do
    case $opt in
        a)
            APP_PATH="$OPTARG"
            ;;
        o)
            OUTPUT_PATH="$OPTARG"
            ;;
        n)
            DMG_NAME="$OPTARG"
            ;;
        v)
            VOLUME_NAME="$OPTARG"
            ;;
        b)
            BACKGROUND_IMAGE="$OPTARG"
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
if [ -z "$APP_PATH" ] || [ -z "$OUTPUT_PATH" ]; then
    echo -e "${RED}Error: Missing required arguments${NC}" >&2
    usage
fi

# Validate app exists
if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}Error: App not found: $APP_PATH${NC}" >&2
    exit 1
fi

# Generate DMG name if not provided
if [ -z "$DMG_NAME" ]; then
    # Get version from app
    VERSION=$("$SCRIPT_DIR/shared-version.sh" get-marketing 2>/dev/null || echo "1.0.0")
    DMG_NAME="Think-$VERSION"
fi

# Create output directory
mkdir -p "$OUTPUT_PATH"

# Full path to DMG
DMG_PATH="$OUTPUT_PATH/$DMG_NAME.dmg"

# Temporary directory for DMG contents
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

echo -e "${BLUE}Creating DMG installer...${NC}"
echo "App: $APP_PATH"
echo "Output: $DMG_PATH"
echo "Volume: $VOLUME_NAME"

# Copy app to temp directory
echo "Copying app..."
cp -R "$APP_PATH" "$TEMP_DIR/"

# Create Applications symlink
ln -s /Applications "$TEMP_DIR/Applications"

# Add background image if provided
if [ -n "$BACKGROUND_IMAGE" ] && [ -f "$BACKGROUND_IMAGE" ]; then
    echo "Adding background image..."
    mkdir -p "$TEMP_DIR/.background"
    cp "$BACKGROUND_IMAGE" "$TEMP_DIR/.background/background.png"
fi

# Calculate required size (app size + 20% buffer)
APP_SIZE_MB=$(du -sm "$APP_PATH" | cut -f1)
DMG_SIZE_MB=$((APP_SIZE_MB * 120 / 100))
echo "App size: ${APP_SIZE_MB}MB, DMG size: ${DMG_SIZE_MB}MB"

# Create initial DMG
echo "Creating DMG..."
hdiutil create -srcfolder "$TEMP_DIR" \
    -volname "$VOLUME_NAME" \
    -fs HFS+ \
    -format UDRW \
    -size "${DMG_SIZE_MB}m" \
    "$DMG_PATH.temp" \
    -quiet

# Mount the DMG
echo "Mounting DMG for customization..."
MOUNT_DIR="/Volumes/$VOLUME_NAME"
hdiutil attach "$DMG_PATH.temp" -readwrite -noverify -noautoopen -quiet

# Wait for mount
sleep 2

# Apply custom settings using AppleScript
echo "Applying custom layout..."
osascript << EOF
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 600, 400}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 80
        if exists file ".background:background.png" then
            set background picture of viewOptions to file ".background:background.png"
        end if
        
        -- Position items
        set position of item "$(basename "$APP_PATH")" of container window to {125, 150}
        set position of item "Applications" of container window to {375, 150}
        
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF

# Hide background folder
if [ -d "$MOUNT_DIR/.background" ]; then
    SetFile -a V "$MOUNT_DIR/.background" 2>/dev/null || true
fi

# Sync and unmount
echo "Finalizing DMG..."
sync
hdiutil detach "$MOUNT_DIR" -quiet

# Convert to compressed read-only DMG
echo "Compressing DMG..."
hdiutil convert "$DMG_PATH.temp" \
    -format UDZO \
    -o "$DMG_PATH" \
    -quiet

# Remove temporary DMG
rm -f "$DMG_PATH.temp"

# Sign the DMG if we have a Developer ID
if security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    echo "Signing DMG..."
    
    # Get the first Developer ID
    IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -n 1 | awk '{print $2}')
    
    if [ -n "$IDENTITY" ]; then
        codesign --force --sign "$IDENTITY" "$DMG_PATH"
        echo -e "${GREEN}✓ DMG signed${NC}"
    fi
fi

# Notarize the DMG (optional, requires notarization setup)
# This would be done in a separate step or script

# Show final info
echo ""
echo -e "${GREEN}✓ DMG created successfully!${NC}"
echo "Path: $DMG_PATH"

# Show DMG info
DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)
echo "Size: $DMG_SIZE"

# Verify DMG
if hdiutil verify "$DMG_PATH" -quiet; then
    echo -e "${GREEN}✓ DMG verification passed${NC}"
else
    echo -e "${YELLOW}⚠️  DMG verification failed${NC}"
fi

echo ""
echo "Next steps:"
echo "1. Test the DMG by double-clicking it"
echo "2. Drag the app to Applications to test installation"
echo "3. Upload to distribution channels"

# Optional: Open the DMG in Finder
# open "$OUTPUT_PATH"