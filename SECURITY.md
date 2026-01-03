# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in Think AI, please report it responsibly.

**Do not open a public GitHub issue for security vulnerabilities.**

Instead, please send an email to **contact@thinkfreely.chat** with:

- A description of the vulnerability
- Steps to reproduce the issue
- The potential impact
- Any suggested fixes (optional)

We will acknowledge your report within 48 hours and aim to provide a fix or mitigation plan within 7 days.

## Scope

This policy applies to:

- The Think AI application code in this repository
- Build and deployment scripts
- Configuration files

This policy does **not** apply to:

- Third-party AI models downloaded from HuggingFace (report to the model author)
- The MLX, llama.cpp, or ESpeakNG frameworks (report to their respective projects)

## Security Considerations

### On-Device AI Processing

Think AI executes AI models locally on your device. Model files are downloaded from HuggingFace Hub and stored in your local Application Support directory. No conversation data is sent to external servers unless you explicitly configure a remote API provider.

### Remote API Keys

If you use the optional remote model providers (OpenAI, Anthropic, Google), API keys are stored in the macOS/iOS Keychain and are never written to disk in plaintext.

### Model Downloads

Models are downloaded over HTTPS from HuggingFace Hub. You are responsible for verifying the trustworthiness of any model you download and for complying with each model's license terms.
