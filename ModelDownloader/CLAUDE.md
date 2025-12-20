# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## ModelDownloader Module Overview

ModelDownloader is a Swift package for downloading AI models from HuggingFace Hub with intelligent format selection, background downloads, and seamless integration with the Think AI ecosystem. It provides a simple **SendableModel → Download → File URL → Execute** workflow.

## Common Development Commands

### Build and Test
```bash
# Build the package
make build

# Run fast unit tests (excludes acceptance tests that download real models)
make test

# Run acceptance tests (downloads real models - slow!)
make test-acceptance

# Run all tests (fast + acceptance)
make test-all

# Run a single test by name
swift test --filter testStreamCancellation

# Run tests matching a pattern
swift test --filter "AsyncStreamTests"
```

### Code Quality
```bash
# Run SwiftLint checks (must pass before committing)
make lint

# Auto-fix SwiftLint issues
make lint-fix

# Find dead code
make deadcode

# Check for code duplication
make duplication

# Run all quality checks
make quality
```

### Development Workflow
```bash
# Watch for changes and re-run tests
make watch-test

# Clean build artifacts
make clean

# Run tests on iOS simulator
make test-ios

# Run tests on all platforms
make test-all-platforms
```

## Architecture and Key Components

### Core Architecture
- **Actor-based design** for thread safety
- **Protocol-driven** with interfaces in `Abstractions` package
- **SendableModel integration** for seamless workflow with Think ecosystem

### Key Components

1. **ModelDownloader** (`Sources/ModelDownloader/ModelDownloader.swift`)
   - Main facade providing all download functionality
   - Singleton `ModelDownloader.shared` for convenience
   - Handles SendableModel → File URL workflow

2. **HuggingFaceDownloader** (`Sources/ModelDownloader/HuggingFace/`)
   - Handles actual downloads from HuggingFace Hub
   - Supports authentication via HF tokens
   - Automatic format selection (MLX, GGUF, CoreML)

3. **BackgroundDownloadManager** (`Sources/ModelDownloader/Download/`)
   - System-managed background downloads
   - Continues downloads when app is suspended
   - Progress tracking and notifications

4. **ModelFileManager** (`Sources/ModelDownloader/FileManager/`)
   - Manages model storage on disk
   - Predictable directory structure: `{baseDir}/{backend}/{modelId}/`
   - Thread-safe file operations

5. **CommunityModelsExplorer** (`Sources/ModelDownloader/Community/`)
   - Discover models from HuggingFace communities
   - Search and filter capabilities
   - Automatic backend detection

### File Organization
Models are stored in:
```
~/Library/Application Support/ThinkAI/Models/
├── mlx/{uuid}/         # MLX models
├── gguf/{uuid}/        # GGUF models  
└── coreml/{uuid}/      # CoreML models (auto-extracted from ZIP)
```

## Important Implementation Details

### SwiftLint Configuration
This module uses a **balanced SwiftLint configuration** (`/.swiftlint.yml`):
- Essential opt-in rules enabled for code quality
- Many strict rules disabled for practical development
- Line length: warning at 120, error at 120
- Force unwrapping, TODOs, and missing docs are allowed
- The root Makefile enforces `--strict` flag

### Testing Approach
- Uses **Swift Testing framework** (not XCTest)
- Test attributes: `@Test`, `@Suite`, `@MainActor`
- Fast tests exclude real downloads via regex filter
- Acceptance tests (`test-acceptance`) download real models

### Background Downloads
When implementing background downloads:
1. Request notification permissions early
2. Handle app delegate callbacks properly
3. Resume downloads after app launch
4. Use `BackgroundDownloadManager` for system integration

### Error Handling
All errors are typed and provide user-friendly messages:
- `ModelAssociation.ModelDownloadError` for download failures
- `ModelAvailability` for validation errors
- Always provide context in error messages

### Thread Safety
- All public APIs are `Sendable` and thread-safe
- File operations use actors for synchronization
- Progress updates are throttled to prevent UI overload

### ZIP Extraction
CoreML models are automatically extracted from ZIP files:
- Extraction happens during download finalization
- Original ZIP is deleted after successful extraction
- Disk space is validated before extraction

## Common Tasks

### Adding a New File Selector
1. Create selector in `Sources/ModelDownloader/HuggingFace/Selection/`
2. Implement file filtering logic
3. Add adapter in `Sources/ModelDownloader/Selection/`
4. Update `FileSelectorFactory` to return new selector
5. Write tests in `Tests/ModelDownloaderTests/HuggingFace/Selection/`

### Adding a New Download Format
1. Update `ModelFormat` enum if needed
2. Create file selector for the format
3. Add format detection in `ModelConverter`
4. Update `getRecommendedFormat` logic
5. Add tests for format-specific behavior

### Debugging Download Issues
1. Enable verbose logging in `ModelDownloaderLogger`
2. Check `~/Library/Application Support/ThinkAI/Models/` for files
3. Verify HuggingFace repository exists and is accessible
4. Check network connectivity and rate limits
5. Use `test-acceptance` with specific test filters

### Running Specific Tests
```bash
# Run a single test method
swift test --filter testStreamCancellation

# Run all tests in a test class
swift test --filter AsyncStreamTests

# Run tests matching a pattern
swift test --filter ".*Download.*"

# Run acceptance test for a specific model
swift test --filter PublicAPIDocumentationTests
```

## Production Features

### Rate Limiting
- Automatic retry with exponential backoff
- Respects HuggingFace API rate limits
- Configurable retry policies

### Disk Space Validation
- Checks available space before downloads
- Validates space for ZIP extraction
- Prevents partial downloads

### Progress Tracking
- Byte-accurate progress updates
- Throttled updates to prevent UI flooding
- Supports pause/resume

### Authentication
- HuggingFace token support via `HFTokenManager`
- Secure token storage in Keychain
- Automatic token injection in requests

## Tips for Development

1. **Always run `make lint` before committing** - The project enforces strict linting
2. **Use `make test` for quick feedback** - Excludes slow acceptance tests
3. **Test with real models sparingly** - Use `make test-acceptance` only when needed
4. **Follow TDD practices** - Write tests first, then implementation
5. **Keep changes focused** - Small, atomic commits are easier to review
6. **Use actors for thread safety** - Don't use locks or semaphores
7. **Handle all error cases** - No silent failures allowed
8. **Document public APIs** - SwiftLint will remind you if you forget