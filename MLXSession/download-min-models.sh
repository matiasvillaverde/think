#!/bin/bash

# Download the smallest model variants used by MLXSession tests.
# This avoids pulling larger, unused models while still covering every architecture.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

MODELS=(
  "Tests/MLXBitnetTests/Resources/bitnet-b1.58-2B-4T-4bit"
  "Tests/MLXCohereTests/Resources/exaone-4.0-1.2b-4bit"
  "Tests/MLXDeepseekTests/Resources/DeepSeek-R1-Distill-Qwen-7B-4bit"
  "Tests/MLXErnieTests/Resources/ERNIE-4.5-0.3B-PT-bf16-ft"
  "Tests/MLXGemma2Tests/Resources/gemma-2-2b-it-4bit"
  "Tests/MLXGemmaTests/Resources/gemma-3-1b-it-4bit"
  "Tests/MLXGemmaTests/Resources/gemma-3n-E2B-it-lm-4bit"
  "Tests/MLXGraniteTests/Resources/granite-3.3-2b-instruct-4bit"
  "Tests/MLXInternLMTests/Resources/internlm2-chat-1_8b-4bit"
  "Tests/MLXKimiVLMTests/Resources/Kimi-VL-A3B-Thinking-4bit"
  "Tests/MLXLlamaTests/Resources/Llama-3.2-1B-Instruct-4bit"
  "Tests/MLXMistralTests/Resources/Mistral-7B-Instruct-v0.2-4bit"
  "Tests/MLXOpenELMTests/Resources/OpenELM-270M-Instruct"
  "Tests/MLXPhiTests/Resources/phi-2-hf-4bit-mlx"
  "Tests/MLXPhi3Tests/Resources/Phi-3.5-mini-instruct-4bit"
  "Tests/MLXPhiMoETests/Resources/Phi-3.5-MoE-instruct-4bit"
  "Tests/MLXQwenTests/Resources/Qwen1.5-0.5B-Chat-4bit"
  "Tests/MLXQwenTests/Resources/Qwen3-0.6B-4bit"
  "Tests/MLXQwenTests/Resources/Qwen3-1.7B-MLX-MXFP4"
  "Tests/MLXSmolLMTests/Resources/LFM2-1.2B-4bit"
  "Tests/MLXSmolLMTests/Resources/SmolLM3-3B-4bit"
  "Tests/MLXStarcoderTests/Resources/starcoder2-3b-4bit"
)

echo "MLXSession Minimal Model Downloader"
echo "This will download the smallest model per architecture used by tests."
echo ""

if ! command -v git &> /dev/null; then
  echo "Error: git is not installed"
  exit 1
fi

if ! command -v git-lfs &> /dev/null; then
  echo "Error: git-lfs is not installed"
  exit 1
fi

git lfs install

count=0
total="${#MODELS[@]}"

for dir in "${MODELS[@]}"; do
  count=$((count + 1))
  echo "[$count/$total] $dir"
  if [ ! -f "$dir/download.sh" ]; then
    echo "Missing download.sh in $dir"
    exit 1
  fi
  (cd "$dir" && bash download.sh)
  echo ""
done

echo "✓ Minimal model downloads complete"
