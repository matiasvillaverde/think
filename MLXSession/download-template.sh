#!/bin/bash

# Git-based download template for MLX models from HuggingFace
# Replace TEMPLATE variables with actual values for each model
#
# Usage:
# - MODEL_NAME: Display name for the model (e.g., "Llama-3.2-1B")
# - REPO_URL: Full HuggingFace repository URL
# - LOCAL_DIR: Target directory (usually "." for current directory)
# - CLEANUP_GIT: Set to "true" to remove .git history after clone (saves disk space)

MODEL_NAME="TEMPLATE_MODEL_NAME"
REPO_URL="https://huggingface.co/mlx-community/TEMPLATE_REPO_NAME"
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

# Create target directory if needed (and not current dir)
if [ "$LOCAL_DIR" != "." ]; then
    mkdir -p "$LOCAL_DIR"
fi

# Clone the repository
echo "Cloning repository: $REPO_URL"
echo "Target directory: $LOCAL_DIR"

# Use shallow clone to save bandwidth and disk space
if git clone --depth 1 "$REPO_URL" temp_clone; then
    echo "✓ Repository cloned successfully"

    # Move contents to target directory
    if [ "$LOCAL_DIR" = "." ]; then
        # Move contents from temp_clone to current directory
        mv temp_clone/* temp_clone/.* . 2>/dev/null || mv temp_clone/* .
        rmdir temp_clone
    else
        # Move temp_clone to target directory
        mv temp_clone "$LOCAL_DIR"
    fi

    # Optional: Clean up git history to save disk space
    if [ "$CLEANUP_GIT" = "true" ]; then
        echo "Removing .git history to save disk space..."
        if [ "$LOCAL_DIR" = "." ]; then
            rm -rf .git
        else
            rm -rf "$LOCAL_DIR/.git"
        fi
        echo "✓ Git history removed"
    fi

    echo "✓ $MODEL_NAME downloaded successfully"

    # Show downloaded files
    echo "Downloaded files:"
    if [ "$LOCAL_DIR" = "." ]; then
        ls -la . | grep -v "^total" | head -10
    else
        ls -la "$LOCAL_DIR" | grep -v "^total" | head -10
    fi

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