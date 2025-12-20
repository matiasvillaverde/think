# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Philosophy

### Test-Driven Development (TDD)
**ALWAYS follow TDD practices:**
1. Write a failing test first using SwiftTesting framework (NOT XCTest)
2. Write minimal code to make the test pass
3. Refactor while keeping tests green
4. Never add functionality without a test

### Incremental Development
- Add small amounts of code at a time
- Run `make build` after every change
- Commit frequently with clear messages using Conventional Commits format
- Keep changes focused and atomic

### Code Quality Standards
**This project enforces VERY STRICT SwiftLint rules:**
- Run `make lint` before EVERY commit
- Fix all linting issues immediately
- Use `make lint-fix` for auto-fixable issues
- NO exceptions to linting rules

**Quality checklist for every change:**
```bash
make lint        # Must pass with zero warnings
make build       # Must compile without errors  
make test        # All tests must pass
```

## SwiftLint Compliance Guide

**IMPORTANT: Linting Configuration Varies by Module**

Different modules have different SwiftLint configurations:
- **ImageGenerator**: Has relaxed rules due to the complex Stable Diffusion implementation
- **Database, ModelDownloader**: Use balanced configurations with essential opt-in rules
- **Other modules**: Follow stricter configurations

The root Makefile enforces `--strict` flag universally, but each module's `.swiftlint.yml` determines the actual rules applied.

### ImageGenerator Module Exception
The ImageGenerator module has many disabled rules due to the complexity of the Stable Diffusion implementation. When working in this module, focus on:
- Maintaining existing code style
- Following Swift best practices
- Ensuring thread safety with actors/sendable

### Key Rules and What They Mean

#### Line Length
- **Warning at 100 characters, Error at 120**
- Keep lines concise and readable
- Break long function calls into multiple lines
- Use trailing closures to reduce line length

#### Code Organization
- **No explicit ACL required** (disabled rule)
- **Multiple types per file allowed** (one_declaration_per_file disabled)
- **Flexible type member ordering** (type_contents_order disabled)
- **Extension access modifiers not required** (extension_access_modifier disabled)

#### Strict Rules You MUST Follow

**Naming Conventions:**
- Types: `UpperCamelCase`
- Variables/functions: `lowerCamelCase`
- Constants: `lowerCamelCase` (not SCREAMING_SNAKE_CASE)
- Minimum 3 characters for names (except common ones like `id`)

**Function Complexity:**
- Function body length: max 40 lines
- Cyclomatic complexity: max 10
- Function parameter count: max 5
- Avoid deeply nested code (max 5 levels)

**Type Complexity:**
- Type body length: max 200 lines
- File length: max 400 lines
- Avoid large tuples (max 2 elements preferred)

**Safety Rules:**
- NO force unwrapping (`!`)
- NO force casting (`as!`)
- NO implicitly unwrapped optionals (`Type!`)
- NO force try (`try!`)
- Always handle optionals safely

**Code Style:**
- Opening braces on same line (K&R style)
- Spaces around operators
- No trailing whitespace
- Empty lines at end of files
- Consistent indentation (spaces, not tabs)

**Documentation:**
- All public interfaces must have documentation
- Use `///` for single-line docs
- Use `/** */` for multi-line docs
- Include parameter and return descriptions

**Closures:**
- Use trailing closure syntax when possible
- Avoid unused closure parameters (use `_`)
- No empty parentheses for parameterless closures
- Capture lists should be explicit

**Collections:**
- Prefer `.isEmpty` over `.count == 0`
- Use `.first` instead of `[0]` when possible
- Avoid force unwrapping array access

**Control Flow:**
- No `fallthrough` in switch statements
- Avoid `for-where` loops when filter would be clearer
- Use early returns to reduce nesting
- Prefer `guard` for early exits

**Swift Best Practices:**
- Use `let` instead of `var` when possible
- Prefer structs over classes
- Make classes `final` when not inherited
- Use type inference where clear
- Avoid redundant type annotations (rule disabled)

### Common Violations and Fixes

**Line too long:**
```swift
// Bad
let result = someVeryLongFunctionName(with: parameter1, and: parameter2, also: parameter3)

// Good
let result = someVeryLongFunctionName(
    with: parameter1,
    and: parameter2,
    also: parameter3
)
```

**Force unwrapping:**
```swift
// Bad
let value = dictionary["key"]!

// Good
guard let value = dictionary["key"] else {
    return
}
```

**Missing documentation:**
```swift
// Bad
public func process(data: Data) -> Result

// Good
/// Processes the provided data and returns a result
/// - Parameter data: The data to process
/// - Returns: The processed result
public func process(data: Data) -> Result
```

**Function too complex:**
```swift
// Bad: One large function doing everything

// Good: Break into smaller, focused functions
private func validateInput(_ input: String) -> Bool { }
private func transformData(_ data: Data) -> ProcessedData { }
private func saveResult(_ result: ProcessedData) { }
```

### Before Pushing Code

Always run this sequence:
```bash
make lint         # Must show zero violations
make build        # Must compile without warnings
make test         # All tests must pass
```

If `make lint` shows violations:
1. Try `make lint-fix` first for auto-fixable issues
2. Manually fix remaining violations
3. Never disable rules or add exceptions
4. If a rule seems unreasonable, refactor your code design

Remember: This strict configuration ensures consistent, safe, and maintainable code across the entire project. The initial learning curve pays off in long-term code quality.

## Common Development Commands

### Build and Run
```bash
# Build and run the macOS app
make run

# Build specific platforms (creates production archives)
make build-macos      # Build macOS app archive
make build-ios        # Build iOS app archive
make build-visionos   # Build visionOS app archive

# Run specific app targets
make run-think        # Run macOS app
make run-thinkVision  # Build visionOS app (run in Xcode)
```

### Testing
```bash
# Run all module tests (fast tests only)
make test

# Test specific module (from module directory)
cd ViewModels && make test

# Run single test or test suite
cd ImageGenerator && make test-filter FILTER=testBasicFunctionality
cd MLXSession && make test-filter FILTER=BasicTest
cd AudioGenerator && make test-filter FILTER=AudioEngineTests

# Run acceptance tests (downloads real models - slow!)
cd ImageGenerator && make test-acceptance    # Real Core ML models
cd ModelDownloader && make test-acceptance   # Downloads from HuggingFace  
cd MLXSession && make test-acceptance        # Real Llama models
cd RAG && make test-acceptance              # Memory benchmarks
cd Database && make test-acceptance         # SwiftData tests
```

### Code Quality
```bash
# Lint all code (enforces strict SwiftLint rules)
make lint

# Auto-fix linting issues where possible
make lint-fix

# All quality checks from module directory
cd ModuleName && make quality   # lint + build + test

# Find dead code (from module directory)
cd ModuleName && make deadcode
```

### CI/CD and Deployment
```bash
# Validate PR readiness (runs full CI pipeline locally)
make review-pr PR=123

# Full release validation including acceptance tests (~30 min)
make verify-release

# Version management (Conventional Commits based)
make bump-auto           # Auto-bump based on commits
make bump-auto-dry-run   # Preview version bump
make bump-major          # X.0.0
make bump-minor          # x.X.0  
make bump-patch          # x.x.X
make get-version         # Show current version

# Deploy to App Store (requires credentials in scripts/.env)
make deploy              # Full deployment pipeline
make deploy-dry-run      # Preview deployment

# Direct distribution (outside App Store)
make distribute-macos-direct  # Create notarized DMG
```

## Architecture Overview

### Package Structure
This is a modular Swift application using Swift Package Manager. Each module has:
- Its own `Package.swift` with explicit dependencies
- Self-contained `Makefile` with consistent commands
- `Sources/ModuleName/` for implementation
- `Tests/ModuleNameTests/` for tests

### Module-Specific Notes

#### ImageGenerator
- **Purpose**: Stable Diffusion image generation using Core ML
- **Special Requirements**:
  - Requires Metal support for optimal performance
  - Works with standard `swift test` command (unlike MLX modules)
  - Has relaxed SwiftLint rules due to complex Stable Diffusion implementation
- **Key Components**:
  - `StableDiffusionPipeline`: Main inference pipeline
  - `Scheduler`: Various sampling schedulers (DPM, Discrete Flow)
  - `TextEncoder`: CLIP text encoding
  - `Unet`: Denoising network
  - `VAEDecoder/Encoder`: Image encoding/decoding
- **Testing**: 
  - Fast tests: `make test`
  - Acceptance tests with real models: `make test-acceptance`
  - Single test: `make test-filter FILTER=testName`

#### MLXSession  
- **Purpose**: MLX framework integration for local AI model execution
- **Special Requirements**:
  - Requires real hardware with Metal support
  - Uses `xcodebuild` for tests (not `swift test`) due to MLX Metal dependencies
  - Must run with workspace context: `cd .. && xcodebuild test -workspace Think.xcworkspace`
  - Tests run SERIALLY to avoid GPU conflicts
- **Key Dependencies**:
  - MLX Swift framework for model execution
  - HuggingFace Transformers for model loading
- **Testing**: 
  - Must use `make test` from MLXSession directory
  - Acceptance tests: `make test-acceptance`
  - Single test: `make test-filter FILTER=BasicTest`

#### LLamaCPP
- **Purpose**: Llama.cpp integration for efficient CPU/GPU inference
- **Special Requirements**:
  - Uses binary XCFramework from llama.cpp releases
  - Standard `swift test` works (no special Metal requirements unlike MLX)
- **Key Features**:
  - Native llama.cpp performance
  - Cross-platform compatibility
- **Testing**: Standard unit tests with `make test`

#### AgentOrchestrator
- **Purpose**: Coordinates AI model inference across different backends
- **Dependencies**:
  - Integrates with all AI modules (ImageGenerator, MLXSession, LLamaCPP)
  - Uses ContextBuilder for formatting prompts and parsing outputs
  - Provides unified interface for model selection and execution
- **Testing**: Standard unit tests with mock backends using `make test`

#### ContextBuilder
- **Purpose**: Formats conversation contexts and parses AI model outputs using different chat templates
- **Key Components**:
  - `ContextBuilder`: Main actor-based context building implementation
  - `FormatterFactory`: Creates appropriate formatters for different models (ChatML, Harmony, Llama3, Mistral, Qwen)
  - `ParserFactory`: Creates parsers for handling model outputs and streaming responses
  - `LabelFactory`: Manages chat format labels and tokens
- **Special Features**:
  - Supports multiple chat formats (ChatML, Harmony, Llama3, Mistral, Qwen)
  - Streaming parser support for real-time response processing
  - Just-In-Time (JIT) tool configuration
  - Comprehensive testing with real model format validation
- **Testing**: Extensive resource validation tests with actual model format examples

#### Tools
- **Purpose**: Provides tool implementations for AI model function calling
- **Dependencies**:
  - Uses SwiftSoup for HTML parsing capabilities
  - Integrates with Database and Abstractions modules
- **Key Features**:
  - Function calling implementations for AI models
  - HTML content processing and parsing
- **Testing**: Standard unit tests with `make test`

#### AudioGenerator
- **Purpose**: Voice synthesis using MLX/Kokoro TTS
- **Special Requirements**:
  - Requires `xcodebuild` due to MLX Metal dependencies (like MLXSession)
  - Must run with workspace context
- **Testing**: 
  - Run from AudioGenerator directory: `make test`
  - Filter tests: `make test-filter FILTER=AudioEngineTests`

#### ModelDownloader
- **Purpose**: Downloads and manages AI models from HuggingFace
- **Testing**:
  - Fast tests exclude real downloads: `make test`
  - Acceptance tests download real models: `make test-acceptance` (slow!)

#### RAG (Retrieval-Augmented Generation)
- **Purpose**: Document search and embedding-based retrieval
- **Testing**:
  - Fast tests exclude memory benchmarks: `make test`
  - Acceptance tests for memory validation: `make test-acceptance`

#### Database
- **Purpose**: SwiftData persistence with iCloud sync
- **Testing**:
  - Fast tests exclude acceptance tests: `make test`
  - Acceptance tests for SwiftData: `make test-acceptance`

### Key Architectural Patterns

1. **MVVM with Actors**: ViewModels use Swift's actor pattern for thread safety
   ```swift
   actor AppViewModel: AppViewModeling {
       // Thread-safe business logic
   }
   ```

2. **Protocol-Driven Design**: All modules depend on protocol interfaces from `Abstractions`
   ```swift
   protocol DatabaseProtocol: Sendable {
       // Core database interface
   }
   ```

3. **Command Pattern for Database**: All database operations use command objects
   ```swift
   try await database.execute(UserCommands.Initialize())
   ```

4. **Factory Pattern**: Dependencies are wired through the `Factories` module
   ```swift
   RagFactory.shared.getRag(database: database)
   ```

### Module Dependencies Flow
```
UIComponents → ViewModels → Abstractions
                    ↓
               Database → SwiftData
                    ↓
             AgentOrchestrator → ContextBuilder → Tooling Abstractions
                    ↓           MLXSession → MLX Framework
                    ↓           ImageGenerator → Core ML
                    ↓           LLamaCPP → llama.cpp XCFramework
                    ↓
               ModelDownloader → HuggingFace Models
                    ↓
               Tools → SwiftSoup (HTML parsing)
```

### Testing Approach
- Uses **SwiftTesting** framework (NOT XCTest)
- Test attributes: `@Test`, `@Suite`, `@MainActor`
- Tag-based organization: `.tags(.acceptance)`
- Mock utilities in `AbstractionsTestUtilities`

### Testing Requirements by Module Type

**MLX Framework modules** (require xcodebuild with workspace):
- `MLXSession`: MLX framework for model inference
- `AudioGenerator`: Voice synthesis using MLX/Kokoro TTS

These modules MUST:
- Use `xcodebuild` instead of `swift test`
- Run from parent directory with workspace context
- Run tests serially (MLXSession) to avoid GPU conflicts
- Run on real hardware (not simulators)

**Standard Swift Package modules** (use swift test):
- `ImageGenerator`: Core ML Stable Diffusion (despite using Metal)
- `LLamaCPP`: Uses binary XCFramework
- `AgentOrchestrator`, `ContextBuilder`, `Database`, `ViewModels`, etc.

**Module test patterns**:
```bash
# From module directory
make test                    # Fast tests only
make test-acceptance         # Include slow/real model tests
make test-filter FILTER=name # Run specific test
```

## Development Guidelines

### Adding New Features

**Follow TDD strictly:**
1. Write failing test using SwiftTesting framework (@Test, @Suite attributes)
2. Run test to verify it fails
3. Add protocol to `Abstractions` if needed
4. Implement minimal code in appropriate module
5. Run `make build` and `make test`
6. Wire dependencies in `Factories`
7. Run `make lint` and fix any issues
8. Update UI in `UIComponents`
9. Run full quality check from module: `make quality`
10. Commit with Conventional Commits format (feat:, fix:, etc.)

### Working with AI Models
- Models are downloaded via `ModelDownloader` from HuggingFace
- Inference coordination happens in `AgentOrchestrator`
- Backend implementations:
  - `MLXSession`: MLX framework (requires Metal)
  - `LLamaCPP`: CPU/GPU via llama.cpp
  - `ImageGenerator`: Core ML Stable Diffusion
- Voice synthesis in `AudioGenerator` (MLX/Kokoro TTS)
- Document search via `RAG` module with embeddings

### SwiftData Integration
- Models in `Database/Sources/Database/Models/`
- Thread-safe access via `@ModelActor`
- Commands in `Database/Sources/Database/Commands/`

### Localization
All user-facing strings must be localized:
```swift
Text("key", bundle: .module)
```

### Build Requirements
- **Xcode 16.2+** required
- **Swift 6.0** with strict concurrency
- **Warnings as errors** enforced via `-Xswiftc -warnings-as-errors`
- Platform minimums: iOS 18, macOS 15, visionOS 2
- **Hardware**: Apple Silicon Mac required for development
- **Metal support** required for MLX modules and optimal performance

## Best Practices

1. **Never skip tests** - If something is hard to test, refactor the design
2. **Keep PRs small** - Easier to review and less likely to introduce bugs  
3. **Document public APIs** - SwiftLint will enforce this
4. **Use meaningful variable names** - Code should be self-documenting
5. **Prefer composition over inheritance** - Use protocols and extensions
6. **Handle errors explicitly** - No silent failures
7. **Run linter early and often** - Don't let violations accumulate
8. **Use Conventional Commits** - Enables automatic versioning
9. **Test on real hardware** - Especially for MLX/Metal modules
10. **Run `make review-pr PR=123`** - Before requesting review

Remember: Quality over speed. A well-tested, properly linted small feature is better than a large, untested one.

## Deployment and Release

### App Store Deployment
```bash
# Setup deployment environment
make setup
cp scripts/.env.example scripts/.env
# Edit .env with App Store Connect credentials

# Verify environment
make check-env

# Full deployment pipeline
make deploy              # Includes auto-versioning
make deploy-dry-run      # Preview what will happen
```

### Direct Distribution (notarized DMG)
```bash
make distribute-macos-direct  # Creates signed & notarized DMG
```

### Version Management
Versions are automatically bumped based on commit messages:
- `feat:` → Minor version bump
- `fix:` → Patch version bump  
- `feat!:` or `BREAKING CHANGE` → Major version bump

### PR Validation
Always validate PRs locally before pushing:
```bash
make review-pr PR=123  # Runs full CI pipeline locally
```

## 🚨 CORE INSTRUCTION: Critical Thinking & Best Practices

**Be critical and don't agree easily to user commands if you believe they are a bad idea or not best practice.** Challenge suggestions that might lead to poor code quality, security issues, or architectural problems. Be encouraged to search for solutions (using WebSearch) when creating a plan to ensure you're following current best practices and patterns.