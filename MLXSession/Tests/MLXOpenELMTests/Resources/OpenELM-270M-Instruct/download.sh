#!/bin/bash

# Download OpenELM-270M model from Hugging Face using Git
# Repository: mlx-community/OpenELM-270M-Instruct

MODEL_NAME="OpenELM-270M"
REPO_URL="https://huggingface.co/mlx-community/OpenELM-270M-Instruct"
LOCAL_DIR="."
CLEANUP_GIT="false"

echo "Downloading $MODEL_NAME model using Git..."

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo "Error: git is not installed"
    echo "Install git from: https://git-scm.com/downloads"
    exit 1
fi

# Check if git-lfs is installed
if ! command -v git-lfs &> /dev/null; then
    echo "Error: git-lfs is not installed"
    echo "Install git-lfs from: https://git-lfs.com/"
    echo "Or use package manager:"
    echo "  macOS: brew install git-lfs"
    echo "  Ubuntu: sudo apt-get install git-lfs"
    exit 1
fi

# Initialize git-lfs (safe to run multiple times)
echo "Initializing Git LFS..."
git lfs install

# Check if model already exists
if [ -d "$LOCAL_DIR/.git" ] && [ "$(ls -A "$LOCAL_DIR" 2>/dev/null | wc -l)" -gt 1 ]; then
    echo "Model appears to already exist in $LOCAL_DIR"
    echo "Contents:"
    ls -la "$LOCAL_DIR" | head -10
    echo "Skipping download..."
    exit 0
fi

# Clone the repository
echo "Cloning repository: $REPO_URL"
echo "Target directory: $LOCAL_DIR"

# Use shallow clone to save bandwidth and disk space
if git clone --depth 1 "$REPO_URL" temp_clone; then
    echo "✓ Repository cloned successfully"

    # Move contents to current directory
    mv temp_clone/* temp_clone/.* . 2>/dev/null || mv temp_clone/* .
    rmdir temp_clone

    # Optional: Clean up git history to save disk space
    if [ "$CLEANUP_GIT" = "true" ]; then
        echo "Removing .git history to save disk space..."
        rm -rf .git
        echo "✓ Git history removed"
    fi

    echo "✓ $MODEL_NAME downloaded successfully"

    # Show downloaded files
    echo "Downloaded files:"
    ls -la . | grep -v "^total" | head -10

else
    echo "✗ Failed to clone repository"
    echo "This could be due to:"
    echo "  - Network connectivity issues"
    echo "  - Repository doesn't exist or is private"
    echo "  - Authentication required (try: git config --global credential.helper store)"
    echo "  - Git LFS bandwidth limit exceeded"

    # Clean up on failure
    rm -rf temp_clone 2>/dev/null
    exit 1
fi

echo "Download complete!"
