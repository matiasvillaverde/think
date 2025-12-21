#!/bin/bash

# Download Kimi-VL-A3B-Thinking-4bit model from Hugging Face using Git
# Repository: mlx-community/Kimi-VL-A3B-Thinking-4bit

MODEL_NAME="Kimi-VL-A3B-Thinking-4bit"
REPO_URL="https://huggingface.co/mlx-community/Kimi-VL-A3B-Thinking-4bit"
LOCAL_DIR="."
CLEANUP_GIT="false"

echo "Downloading $MODEL_NAME model using Git..."

if ! command -v git &> /dev/null; then
    echo "Error: git is not installed"
    exit 1
fi

if ! command -v git-lfs &> /dev/null; then
    echo "Error: git-lfs is not installed"
    exit 1
fi

echo "Initializing Git LFS..."
git lfs install

if [ -d "$LOCAL_DIR/.git" ] && [ "$(ls -A "$LOCAL_DIR" 2>/dev/null | wc -l)" -gt 1 ]; then
    echo "Model appears to already exist in $LOCAL_DIR"
    echo "Contents:"
    ls -la "$LOCAL_DIR" | head -10
    echo "Skipping download..."
    exit 0
fi

echo "Cloning repository: $REPO_URL"
echo "Target directory: $LOCAL_DIR"

if git clone --depth 1 "$REPO_URL" temp_clone; then
    echo "✓ Repository cloned successfully"

    mv temp_clone/* temp_clone/.* . 2>/dev/null || mv temp_clone/* .
    rmdir temp_clone

    if [ "$CLEANUP_GIT" = "true" ]; then
        echo "Removing .git history to save disk space..."
        rm -rf .git
        echo "✓ Git history removed"
    fi

    echo "✓ $MODEL_NAME downloaded successfully"
    echo "Downloaded files:"
    ls -la . | grep -v "^total" | head -10
else
    echo "✗ Failed to clone repository"
    rm -rf temp_clone 2>/dev/null
    exit 1
fi

echo "Download complete!"
