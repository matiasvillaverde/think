#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

echo "LLamaCPP test model fetch helper"
echo
echo "This repo does not ship GGUF weights."
echo
echo "Option A: point tests at local files:"
echo "  export LLAMACPP_TEST_MODEL_PATH=/path/to/Qwen3-0.6B-UD-IQ1_S.gguf"
echo "  export LLAMACPP_ACCEPTANCE_MODEL_PATH=/path/to/Qwen3-0.6B-BF16.gguf"
echo
echo "Option B: download via direct URLs (you provide the URLs):"
echo "  export LLAMACPP_TEST_MODEL_URL=https://.../Qwen3-0.6B-UD-IQ1_S.gguf"
echo "  export LLAMACPP_ACCEPTANCE_MODEL_URL=https://.../Qwen3-0.6B-BF16.gguf"
echo

download() {
  local url="$1"
  local out="$2"
  if [[ -f "$out" ]]; then
    echo "Already exists: $out"
    return 0
  fi
  echo "Downloading -> $out"
  curl -L --fail --retry 3 --retry-delay 2 -o "$out.part" "$url"
  mv "$out.part" "$out"
}

if [[ -n "${LLAMACPP_TEST_MODEL_URL:-}" ]]; then
  download "$LLAMACPP_TEST_MODEL_URL" "$DIR/Qwen3-0.6B-UD-IQ1_S.gguf"
  echo "Wrote: $DIR/Qwen3-0.6B-UD-IQ1_S.gguf"
fi

if [[ -n "${LLAMACPP_ACCEPTANCE_MODEL_URL:-}" ]]; then
  download "$LLAMACPP_ACCEPTANCE_MODEL_URL" "$DIR/Qwen3-0.6B-BF16.gguf"
  echo "Wrote: $DIR/Qwen3-0.6B-BF16.gguf"
fi

echo
echo "Done. Export env vars if needed:"
echo "  export LLAMACPP_TEST_MODEL_PATH=\"$DIR/Qwen3-0.6B-UD-IQ1_S.gguf\""
echo "  export LLAMACPP_ACCEPTANCE_MODEL_PATH=\"$DIR/Qwen3-0.6B-BF16.gguf\""

