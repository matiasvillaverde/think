#!/bin/bash

# Download InternLM2.5-7B model from Hugging Face using Git
# Repository: mlx-community/internlm2_5-7b-chat-4bit

MODEL_NAME="InternLM2.5-7B"
REPO_URL="https://huggingface.co/mlx-community/internlm2_5-7b-chat-4bit"
TARGET_DIR="internlm2_5-7b-chat-4bit"
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
if [ -d "$TARGET_DIR/.git" ] && [ "$(ls -A "$TARGET_DIR" 2>/dev/null | wc -l)" -gt 1 ]; then
    echo "Model appears to already exist in $TARGET_DIR"
    echo "Contents:"
    ls -la "$TARGET_DIR" | head -10
    echo "Skipping download..."
    exit 0
fi

# Clone the repository

echo "Cloning repository: $REPO_URL"
echo "Target directory: $TARGET_DIR"

# Use shallow clone to save bandwidth and disk space
if git clone --depth 1 "$REPO_URL" temp_clone; then
    echo "✓ Repository cloned successfully"

    # Move contents to target directory
    mkdir -p "$TARGET_DIR"
    mv temp_clone/* temp_clone/.* "$TARGET_DIR" 2>/dev/null || mv temp_clone/* "$TARGET_DIR"
    rmdir temp_clone

    # Optional: Clean up git history to save disk space
    if [ "$CLEANUP_GIT" = "true" ]; then
        echo "Removing .git history to save disk space..."
        rm -rf "$TARGET_DIR/.git"
        echo "✓ Git history removed"
    fi

    echo "✓ $MODEL_NAME downloaded successfully"

    # Show downloaded files
    echo "Downloaded files:"
    ls -la "$TARGET_DIR" | grep -v "^total" | head -10

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
