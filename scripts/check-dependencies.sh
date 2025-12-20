#!/bin/bash
# Check and install dependencies for Think CI/CD pipeline
# This script verifies all required tools are installed and provides
# installation instructions for missing dependencies

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track if any dependencies are missing
MISSING_DEPS=0

# Function to check if a command exists
check_command() {
    local cmd="$1"
    local install_cmd="$2"
    local description="$3"
    
    if command -v "$cmd" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $cmd - $description"
        return 0
    else
        echo -e "${RED}✗${NC} $cmd - $description"
        echo -e "  ${YELLOW}Install with:${NC} $install_cmd"
        MISSING_DEPS=1
        return 1
    fi
}

# Function to check Xcode Command Line Tools
check_xcode_tools() {
    if xcode-select -p >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Xcode Command Line Tools"
        return 0
    else
        echo -e "${RED}✗${NC} Xcode Command Line Tools"
        echo -e "  ${YELLOW}Install with:${NC} xcode-select --install"
        MISSING_DEPS=1
        return 1
    fi
}

# Function to check if Homebrew is installed
check_homebrew() {
    if command -v brew >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Homebrew package manager"
        return 0
    else
        echo -e "${RED}✗${NC} Homebrew package manager"
        echo -e "  ${YELLOW}Install with:${NC} /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        MISSING_DEPS=1
        return 1
    fi
}

echo "🔍 Checking CI/CD Dependencies"
echo "=============================="
echo ""

# Check Xcode Command Line Tools first
check_xcode_tools

# Check Homebrew
check_homebrew

echo ""
echo "Required Tools:"
echo "--------------"

# Check required commands
check_command "git" "brew install git" "Version control system"
check_command "xcodebuild" "Install Xcode from App Store" "Xcode build tool"
check_command "xcbeautify" "brew install xcbeautify" "Xcode output formatter"
check_command "jq" "brew install jq" "JSON processor"
check_command "gh" "brew install gh" "GitHub CLI"
check_command "git-cliff" "brew install git-cliff" "Changelog generator"
check_command "curl" "Should be pre-installed on macOS" "HTTP client"
check_command "openssl" "brew install openssl" "Cryptography toolkit"
check_command "plutil" "Should be pre-installed on macOS" "Property list utility"

# Check for Python (needed for some scripts)
if command -v python3 >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} python3 - Python interpreter"
else
    echo -e "${YELLOW}⚠${NC} python3 - Python interpreter (optional)"
    echo -e "  ${YELLOW}Install with:${NC} brew install python3"
fi

echo ""

# Check for .env file
if [ -f "$(dirname "$0")/.env" ]; then
    echo -e "${GREEN}✓${NC} .env file exists"
else
    echo -e "${YELLOW}⚠${NC} .env file not found"
    echo -e "  ${YELLOW}Create with:${NC} cp scripts/.env.example scripts/.env"
    echo -e "  Then edit scripts/.env with your credentials"
fi

# Check for API key file
if ls "$(dirname "$0")"/AuthKey_*.p8 >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} App Store Connect API key file found"
else
    echo -e "${YELLOW}⚠${NC} App Store Connect API key file not found"
    echo -e "  Download from App Store Connect and place in scripts/ directory"
fi

echo ""

# Summary
if [ $MISSING_DEPS -eq 0 ]; then
    echo -e "${GREEN}✅ All required dependencies are installed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some dependencies are missing.${NC}"
    echo ""
    echo "To install all missing Homebrew packages at once:"
    echo "brew install xcbeautify jq gh git-cliff openssl"
    echo ""
    echo "Note: Xcode must be installed from the App Store"
    exit 1
fi