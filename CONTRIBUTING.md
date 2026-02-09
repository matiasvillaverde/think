# Contributing to Think AI

Thank you for your interest in contributing to Think AI! This guide covers the essentials for contributing to our multi-platform AI assistant.

## Code of Conduct

By participating in this project, you agree to follow `CODE_OF_CONDUCT.md`.

## What To Contribute

- Bug fixes (especially crashes, data-loss risks, sandbox/permissions issues)
- Documentation improvements (README, module CLAUDE docs, examples)
- Test coverage (SwiftTesting; deterministic tests)
- New backends or providers via `Abstractions` + DI via `Factories`

## Getting Started

1. Fork and clone the repository
2. Run `make setup`

For detailed setup and CI/CD workflows, see [CI.md](CI.md).

## Requirements

- Xcode 16.2+ and Swift 6
- Apple Silicon Mac recommended (MLX/Metal)
- Makefile-only workflow (do not run from Xcode when developing; use `make`)

## Development Process

We follow Test-Driven Development (TDD):

1. Write tests first using **SwiftTesting framework** (NOT XCTest)
2. Implement minimal code to pass tests
3. Refactor while keeping tests green
4. Run `make lint`, then `make build`, then `make test` before committing

## Project Structure (Where Things Go)

- `Abstractions/`: protocols, models, errors (contracts). Prefer depending on this only.
- `Database/`: SwiftData persistence and commands.
- Backends: `MLXSession/`, `LLamaCPP/`, `ImageGenerator/`, `ModelDownloader/` (depend on `Abstractions`).
- Orchestration: `AgentOrchestrator/` coordinates backends via protocols.
- Composition/DI: `Factories/` creates implementations and injects them.
- UI: `ViewModels/`, `UIComponents/`, apps in `Think/` and `Think Vision/`.

## Commit Messages

We use [Conventional Commits](https://www.conventionalcommits.org/) for automatic versioning:

```
<type>[optional scope]: <description>
```

### Types
- `feat`: New features → MINOR bump
- `fix`: Bug fixes → PATCH bump
- `feat!` or `BREAKING CHANGE`: Breaking changes → MAJOR bump

### Examples
```bash
feat: add document search with RAG support
fix(auth): handle expired tokens correctly
feat!: migrate to SwiftData 2.0
```

## Code Style

- We run SwiftLint with the strictest possible configuration
- Localize all user-facing strings:
  ```swift
  String(localized: "key", comment: "description", bundle: .module)
  ```

## Pull Request Process

1. Create feature branch: `git checkout -b feat/your-feature`
2. Follow TDD practices
3. Validate locally: `make review-pr PR=your-pr-number`
4. Commit with conventional format
5. Create PR with:
   - Clear description
   - Linked issues
   - Screenshots for UI changes

### PR Checklist

- `make lint` passes
- `make build` passes
- `make test` passes (or explain why a subset was run)
- UI changes include before/after screenshots (macOS + iOS when relevant)
- No secrets committed (double-check `scripts/.env` and key files)

## Testing Guidelines

- Use SwiftTesting framework exclusively
- Write descriptive test names
- Mock external dependencies
- Keep tests fast and isolated

## Module Development

When creating new modules:
1. Use existing modules as templates
2. Include standard Makefile
3. Configure SwiftLint
4. Update root Makefile's MODULES list
5. Wire dependencies in Factories module

## Getting Help

- Check existing issues and discussions
- Review architecture documentation
- Ask questions in pull requests

Thank you for contributing!
