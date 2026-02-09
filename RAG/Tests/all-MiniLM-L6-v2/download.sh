#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$ROOT_DIR/model.safetensors"

if [[ -f "$OUT" ]]; then
  echo "Already present: $OUT"
  exit 0
fi

URL="https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2/resolve/main/model.safetensors"

echo "Downloading model weights to: $OUT"
echo "From: $URL"

curl -L --fail --retry 3 --retry-delay 2 -o "$OUT" "$URL"

echo "Done."

