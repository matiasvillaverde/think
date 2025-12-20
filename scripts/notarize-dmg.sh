#!/bin/bash
# Notarize DMG for direct distribution outside App Store

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load environment variables
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
fi

# Get DMG path from argument
DMG_PATH="$1"
if [ -z "$DMG_PATH" ]; then
    echo -e "${RED}Error: DMG path required${NC}"
    echo "Usage: $0 <dmg-path>"
    exit 1
fi

if [ ! -f "$DMG_PATH" ]; then
    echo -e "${RED}Error: DMG not found: $DMG_PATH${NC}"
    exit 1
fi

# Check required credentials
if [ -z "$APPSTORE_KEY_ID" ] || [ -z "$APPSTORE_ISSUER_ID" ]; then
    echo -e "${RED}Error: Missing API credentials${NC}"
    echo "Please set APPSTORE_KEY_ID and APPSTORE_ISSUER_ID in scripts/.env"
    exit 1
fi

if [ -z "$APP_STORE_CONNECT_API_KEY_PATH" ] || [ ! -f "$APP_STORE_CONNECT_API_KEY_PATH" ]; then
    echo -e "${RED}Error: API key file not found${NC}"
    echo "Please set APP_STORE_CONNECT_API_KEY_PATH in scripts/.env"
    exit 1
fi

echo -e "${BLUE}📤 Submitting DMG for notarization...${NC}"
echo "File: $(basename "$DMG_PATH")"

# Submit for notarization and wait
if xcrun notarytool submit "$DMG_PATH" \
    --key-id "$APPSTORE_KEY_ID" \
    --issuer "$APPSTORE_ISSUER_ID" \
    --key "$APP_STORE_CONNECT_API_KEY_PATH" \
    --wait \
    --timeout 30m \
    --output-format json > /tmp/notarization_result.json 2>&1; then
    
    # Parse the result
    STATUS=$(cat /tmp/notarization_result.json | jq -r '.status' 2>/dev/null || echo "unknown")
    
    if [ "$STATUS" = "Accepted" ]; then
        echo -e "${GREEN}✓ Notarization accepted!${NC}"
        
        # Staple the ticket to the DMG
        echo -e "${BLUE}📎 Stapling notarization ticket...${NC}"
        if xcrun stapler staple "$DMG_PATH"; then
            echo -e "${GREEN}✓ Notarization ticket stapled${NC}"
            
            # Verify the stapling
            echo -e "${BLUE}🔍 Verifying notarization...${NC}"
            if xcrun stapler validate "$DMG_PATH"; then
                echo -e "${GREEN}✓ DMG validated successfully${NC}"
            else
                echo -e "${YELLOW}⚠ Validation failed but DMG is notarized${NC}"
            fi
        else
            echo -e "${YELLOW}⚠ Failed to staple ticket (DMG is still notarized)${NC}"
        fi
        
        echo -e "${GREEN}✨ DMG is notarized and ready for distribution!${NC}"
    else
        echo -e "${RED}✗ Notarization failed with status: $STATUS${NC}"
        cat /tmp/notarization_result.json | jq '.' 2>/dev/null
        exit 1
    fi
else
    echo -e "${RED}Error: Notarization submission failed${NC}"
    cat /tmp/notarization_result.json 2>&1
    exit 1
fi

# Clean up
rm -f /tmp/notarization_result.json

echo ""
echo -e "${GREEN}Summary:${NC}"
echo "  • DMG: $(basename "$DMG_PATH")"
echo "  • Status: Notarized ✓"
echo "  • Ticket: Stapled ✓"
echo "  • Ready for distribution outside App Store"