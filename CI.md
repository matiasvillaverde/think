# Think CI/CD Documentation

## Overview

Think uses a **hybrid Makefile architecture** that enables both autonomous package development and centralized orchestration. This approach provides:

- Package-level autonomy with self-contained Makefiles
- Root-level orchestration through delegating commands
- Consistent interface for local development and CI/CD
- Quality enforcement with warnings-as-errors and strict linting

## Getting Started

### Initial Setup

```bash
# Install dependencies and git hooks
make setup
./scripts/setup-hooks.sh

# Configure credentials (for deployment)
cp scripts/.env.example scripts/.env
# Edit .env with your App Store Connect credentials

# Verify setup
make check-env
```

### Required Tools

Run `make setup` to check and install all required dependencies.

## Architecture

### Supported Modules

All modules have full CI/CD support with consistent Makefile patterns:

- **Core**: Abstractions, Database, ContextBuilder, Factories
- **UI**: UIComponents, ViewModels
- **AI/ML**: AgentOrchestrator, MLXSession, LLamaCPP, ImageGenerator, ModelDownloader, AudioGenerator, RAG
- **Tools**: AppStoreConnectCLI
- **Others**: Basic Makefile support, extensible pattern

### Module-Specific Requirements

#### MLX/Metal Framework Modules (MLXSession, ImageGenerator, AudioGenerator)
- Must use `xcodebuild` instead of `swift test` due to Metal/Core ML requirements
- Tests must run on real hardware (not simulators)
- MLXSession requires workspace context: `cd .. && xcodebuild test -workspace Think.xcworkspace`

#### Standard Swift Package Modules (LLamaCPP, AgentOrchestrator)
- Use standard `swift test` command
- LLamaCPP uses binary XCFramework for llama.cpp integration
- AgentOrchestrator coordinates inference across all backends

#### ModelDownloader
- Fast tests exclude `PublicAPIDocumentationTests`
- Acceptance tests download real models from HuggingFace
- Test filter: `--filter "^(?!.*PublicAPIDocumentationTests).*$$"`

#### RAG
- Fast tests exclude `MemoryBenchmarkTests`
- Acceptance tests validate memory usage patterns

## Development Workflow

### Daily Development Commands

**From project root:**
```bash
make test      # Test all modules
make build     # Build all modules
make lint      # Lint all modules (includes apps)
make clean     # Clean all modules and Xcode artifacts
```

**From package directory:**
```bash
make test          # Run fast tests
make lint          # Check code style
make lint-fix      # Auto-fix issues
make build         # Build package
make build-ci      # Build with warnings-as-errors
make quality       # All quality checks
```

### App Commands

```bash
make run                # Build and run Think (macOS)
make run-think      # Same as above
make run-thinkVision # Build ThinkVision (visionOS)
```

### Git Hooks

- **Pre-commit**: Runs fast tests and linting for modified modules
- **Pre-push**: Comprehensive tests with warnings-as-errors
- Skip with `--no-verify` (use sparingly)

## Testing Strategy

### Test Categories

1. **Fast Tests** (`make test`)
   - Unit tests with mocks
   - Must complete in <30 seconds
   - Run frequently during development

2. **Acceptance Tests** (`make test-acceptance`)
   - Real-world scenarios
   - May take longer to execute
   - Run before releases

3. **Platform Tests** (`make test-ios`, `make test-all-platforms`)
   - Cross-platform validation
   - Ensures compatibility across iOS, macOS, visionOS

## Release & Deployment

### Version Management

```bash
make get-version      # Show current version
make bump-patch       # 2.0.23 → 2.0.24
make bump-minor       # 2.0.23 → 2.1.0
make bump-major       # 2.0.23 → 3.0.0
make bump-auto        # Analyze commits for semantic version
```

Uses Conventional Commits:
- `feat:` → MINOR bump
- `fix:` → PATCH bump
- `BREAKING CHANGE:` → MAJOR bump

### PR Review & Validation

```bash
# Review specific PR
make review-pr PR=123

# Comprehensive release validation
make verify-release
```

**verify-release** includes:
1. Standard PR review
2. Multi-platform Release builds
3. Acceptance tests with real AI models (10-30 minutes)

### App Store Deployment

#### Automated Deployment

```bash
make deploy           # Full automated deployment with auto-versioning
make deploy-dry-run   # Preview what would happen
```

The deploy command:
1. Auto-bumps version based on conventional commits
2. Verifies release readiness
3. Builds and exports all platforms
4. Creates DMG for macOS
5. Generates changelog
6. Creates GitHub release
7. Updates App Store Connect versions
8. Uploads metadata
9. Submits to App Store (with confirmation prompts)

#### Individual Deployment Steps

```bash
# Building archives
make build-ios              # Archive for iOS
make build-macos            # Archive for macOS
make build-visionos         # Archive for visionOS

# Exporting apps
make export-ios             # Create .ipa
make export-macos           # Create .app
make export-visionos        # Create .ipa
make create-dmg-macos       # Create macOS DMG installer

# Metadata management (using AppStoreConnectCLI)
make download-metadata      # Download all platforms
make upload-metadata        # Upload all platforms
make validate-metadata      # Validate metadata

# App Store submission
make submit-ios             # Submit iOS to App Store
make submit-macos           # Submit macOS to App Store
make submit-visionos        # Submit visionOS to App Store

# Version management in App Store Connect
make manage-app-store-versions  # Create/update all platform versions
```

## Adding New Packages

1. Create `PackageName/Makefile` (use existing modules as templates)
2. Add SwiftLint configuration
3. Add to Package.swift:
   ```swift
   swiftSettings: [.unsafeFlags(["-warnings-as-errors"])]
   ```
4. Update root Makefile's MODULES variable
5. Document in README.md

## Best Practices

1. Run `make test` after each change
2. Use semantic commit messages for automatic versioning
3. Run `make verify-release` before deployments
4. Keep package Makefiles simple and consistent
5. Document special requirements in module Makefiles

### Before Committing

```bash
# From module directory
make lint
make test
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| SwiftLint errors | Run `make lint-fix` |
| Build issues | Run `make clean-all` then rebuild |
| MLX errors | Ensure using `xcodebuild` not `swift test` |
| Missing dependencies | Run `make setup` |
