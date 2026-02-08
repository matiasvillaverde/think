# Test Models (Not Committed)

This directory is intentionally kept out of git for large `.gguf` model files.

LLamaCPP tests can run in two modes:

- **Unit tests**: require a small GGUF model via `LLAMACPP_TEST_MODEL_PATH`
- **Acceptance tests**: require a higher quality GGUF model via `LLAMACPP_ACCEPTANCE_MODEL_PATH`

To set up models:

```bash
# From the repo root
export LLAMACPP_TEST_MODEL_PATH="/absolute/path/to/Qwen3-0.6B-UD-IQ1_S.gguf"
export LLAMACPP_ACCEPTANCE_MODEL_PATH="/absolute/path/to/Qwen3-0.6B-BF16.gguf"

cd LLamaCPP
make test
```

If these env vars are not set (or point to invalid files), tests that require a model will be skipped.

