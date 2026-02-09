<p align="center">
  <img src="Think/Assets.xcassets/AppIcon.appiconset/rounded_icon.png" width="128" alt="Think app icon" />
</p>

# Think (OpenClaw App)

Think is an Apple‑platform app inspired by OpenClaw and transformed into a native iOS/macOS/visionOS experience.

**Status:** experimental, under active development, and **not ready for production use**.

<p align="center">
  <a href="LICENSE"><img alt="License" src="https://img.shields.io/badge/license-MIT-black"></a>
  <img alt="Platforms" src="https://img.shields.io/badge/platforms-iOS%2018%2B%20%7C%20macOS%2015%2B%20%7C%20visionOS%202%2B-black">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-6-black">
  <img alt="Build" src="https://img.shields.io/badge/build-Makefile%20only-black">
</p>

**Quick links:** [Screenshots](#screenshots) · [ThinkCLI](#thinkcli) · [LLM Inference Modes](#llm-inference-modes) · [OpenClaw Remote Gateway](#openclaw-remote-gateway) · [Contributing](CONTRIBUTING.md)

## Purpose

The goal is to make a tool that feels like OpenClaw but is easier to install, runs locally, and can live safely in a sandboxed environment (especially on iOS). Think uses MLX on Apple Silicon to run models on‑device.

On capable Apple Silicon machines, Think is intended as the foundation for a personal assistant (or “ghost”) that lives on your computer and runs locally.

## Why This Repo Looks Like A “Landing Page”

We sampled the top 100 GitHub repos tagged `artificial-intelligence` (by stars) and extracted common patterns from their READMEs. The most common “this repo feels legit” signals were:

- Clear value prop + quick links
- Badges (license/platform/build status)
- Install + Quickstart
- Examples / demos / screenshots
- Documentation index and architecture notes
- Community health files (CONTRIBUTING, CODE_OF_CONDUCT, SECURITY) and templates

In our sample (98 READMEs fetched), we saw: docs sections (72), examples (69), badges (67), install instructions (64), screenshots/media (58), contributing sections (45), citations (29), roadmaps (11).

## Status

This project is under active development. Expect breaking changes, missing features, and incomplete documentation.

## What This Is

- An app‑focused implementation inspired by OpenClaw for Apple platforms.
- Designed to run in a sandbox (required on iOS) with a clear security model.
- Built with Swift, SwiftUI, and a modular architecture.
- Can connect to a remote OpenClaw Gateway instance over WebSocket (pairing required).

## What This Is Not (Yet)

- A stable or fully supported release.
- A complete replacement for the original OpenClaw tooling.

## Platforms

- iOS 18+
- macOS 15+
- visionOS 2+

## Repository Layout

See `AGENTS.md` and `CLAUDE.md` for architecture and contribution guidance.

## Build The App (macOS)

Development is Makefile-driven:

```bash
make lint
make build
make test
make run
```

## Screenshots

This section is intentionally “large” so the README can act like a landing page.

<details>
  <summary><strong>macOS / iOS / visionOS screenshots (coming soon)</strong></summary>
  <br />

  <p>
    Add screenshots in a future PR and wire them here.
    Suggested layout:
  </p>

  <table>
    <tr>
      <td><strong>macOS</strong><br />Main chat, model picker, tools</td>
      <td><strong>iOS</strong><br />Chat + model download</td>
      <td><strong>visionOS</strong><br />Sidebar + chat</td>
    </tr>
    <tr>
      <td>(drop image)</td>
      <td>(drop image)</td>
      <td>(drop image)</td>
    </tr>
  </table>
</details>

## ThinkCLI

ThinkCLI is a Swift executable named `think` (built with `swift-argument-parser`) that can manage chats, models, tools, RAG, and remote gateway connectivity from the terminal.

### Install (One Command)

This installs `think` into a standard `bin` directory (`/opt/homebrew/bin`, `/usr/local/bin`, or `~/.local/bin` depending on what is writable).

```bash
curl -fsSL https://raw.githubusercontent.com/matiasvillaverde/think/main/scripts/install-think-cli.sh | bash
```

### Install From a Local Clone

```bash
cd ThinkCLI
make install
```

### Quick Usage

```bash
think --help
think doctor
think models list
think chat list
```

## LLM Inference Modes

LLM inference can be:

1. Remote (API key): OpenRouter, OpenAI, Anthropic, Google Gemini.
2. MLX models that run natively on Apple Silicon.
3. llama.cpp models (GGUF).
4. Connect to an instance of OpenClaw running remotely, and use the app as a client (via the OpenClaw Gateway).

Remote API keys:
- `OPENROUTER_API_KEY`
- `OPENAI_API_KEY`
- `ANTHROPIC_API_KEY`
- `GOOGLE_API_KEY` or `GEMINI_API_KEY`

For remote provider details, see `RemoteSession/CLAUDE.md`.

## OpenClaw Remote Gateway

Think can connect to a remote OpenClaw Gateway for “OpenClaw-style” remote operations.

See `OPENCLAW_REMOTE.md` for setup instructions (App UI and ThinkCLI).

## Documentation Index

- `AGENTS.md`: architecture and module layout
- `CLAUDE.md`: build/test rules and module-specific gotchas
- `CHANGELOG.md`: notable changes (Keep a Changelog format)
- `OPENCLAW_REMOTE.md`: OpenClaw Gateway setup (UI + ThinkCLI)
- `OPENCLAW_GAPS.md`: OpenClaw parity backlog
- `CI.md`: CI/CD workflows

## License

MIT. See `LICENSE`.
