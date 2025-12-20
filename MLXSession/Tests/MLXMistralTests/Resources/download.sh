#!/bin/bash

# Download Mistral model from Hugging Face
# Repository: mlx-community/Mistral-7B-Instruct-v0.2-4bit

echo "Downloading Mistral-7B-Instruct model..."

# Check if huggingface-cli is installed
if ! command -v huggingface-cli &> /dev/null; then
    echo "Error: huggingface-cli is not installed"
    echo "Install with: pip install huggingface-hub"
    exit 1
fi

# Create directory for the model
mkdir -p Mistral-7B-Instruct-v0.2-4bit

# Download the model
huggingface-cli download mlx-community/Mistral-7B-Instruct-v0.2-4bit --local-dir Mistral-7B-Instruct-v0.2-4bit

echo "Download complete!"