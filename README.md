# Think (OpenClaw App)

Think is an Apple‑platform app inspired by OpenClaw and transformed into a native iOS/macOS/visionOS experience. It is an experiment, and it is **not ready for production use**. Only use it if you understand how it works.

## Purpose

The goal is to make a tool that feels like OpenClaw but is easier to install, runs locally, and can live safely in a sandboxed environment (especially on iOS). Think uses MLX on Apple Silicon to run models on‑device.

On capable Apple Silicon machines, Think is intended as the foundation for a personal assistant (or “ghost”) that lives on your computer and runs locally.

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

## OpenClaw Remote Gateway

Think can connect to a remote OpenClaw Gateway for “OpenClaw-style” remote operations.

See `OPENCLAW_REMOTE.md` for setup instructions (App UI and ThinkCLI).

## License

MIT. See `LICENSE`.
