#!/bin/bash

# Download all MLXSession models using their individual download scripts
# This script calls each model's download.sh script sequentially
# Now uses Git with Git LFS instead of huggingface-cli

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}MLXSession Model Downloader (Git-based)${NC}"
echo -e "${YELLOW}⚠️  This will download approximately 20-30GB of models${NC}"
echo -e "${YELLOW}Models will be downloaded sequentially to avoid system overload${NC}"
echo ""

# Check Git prerequisites
echo -e "${BLUE}Checking prerequisites...${NC}"

if ! command -v git &> /dev/null; then
    echo -e "${RED}✗ Git is not installed${NC}"
    echo "Please install Git from: https://git-scm.com/downloads"
    exit 1
fi

if ! command -v git-lfs &> /dev/null; then
    echo -e "${RED}✗ Git LFS is not installed${NC}"
    echo "Please install Git LFS from: https://git-lfs.com/"
    echo "Package manager installation:"
    echo "  macOS: brew install git-lfs"
    echo "  Ubuntu: sudo apt-get install git-lfs"
    exit 1
fi

echo -e "${GREEN}✓ Git and Git LFS are available${NC}"

# Initialize Git LFS (safe to run multiple times)
echo -e "${BLUE}Initializing Git LFS...${NC}"
git lfs install

echo ""
echo -n "Continue with download? (y/N): "
read -r response

if [ "$response" != "y" ] && [ "$response" != "Y" ]; then
    echo "Download cancelled"
    exit 0
fi

# Find all download.sh scripts
download_scripts=$(find Tests -name "download.sh" -type f | sort)
total=$(echo "$download_scripts" | wc -l | tr -d ' ')
count=0

echo -e "${BLUE}Found $total models to download${NC}"
echo ""

# Download each model
for script in $download_scripts; do
    count=$((count + 1))
    dir=$(dirname "$script")
    model_name=$(basename "$(dirname "$script")")
    
    echo -e "${BLUE}[$count/$total] Downloading $model_name...${NC}"
    echo -e "${BLUE}Location: $dir${NC}"
    
    # Check if model already exists (look for key model files or git repo)
    if [ -f "$dir/model.safetensors" ] || [ -f "$dir/model.safetensors.index.json" ] || [ -d "$dir/.git" ]; then
        echo -e "${YELLOW}Model already downloaded, skipping...${NC}"
    else
        # Make script executable and run it
        chmod +x "$script"
        cd "$dir" && bash download.sh
        cd - > /dev/null
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ $model_name downloaded successfully${NC}"
        else
            echo -e "${RED}✗ Failed to download $model_name${NC}"
        fi
    fi
    
    # Small delay between downloads
    if [ $count -lt $total ]; then
        echo -e "${YELLOW}Waiting 2 seconds before next download...${NC}"
        sleep 2
    fi
    echo ""
done

echo -e "${GREEN}✓ All downloads complete!${NC}"
echo ""
echo "To check disk usage, run:"
echo "  du -sh Tests/*/Resources/*/"