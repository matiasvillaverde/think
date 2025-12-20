# CLAUDE.md

Project instructions for Claude Code. This file is automatically loaded.

## Quick Reference

```bash
make lint && make build && make test   # Quality check (run before commits)
make run                               # Build and run macOS app
cd ModuleName && make test             # Test specific module
```

## Hierarchical Documentation

This project uses **hierarchical CLAUDE.md files**. Always check for module-specific instructions:

| Location | Purpose |
|----------|---------|
| `/CLAUDE.md` (this file) | Universal project rules |
| `/ModuleName/CLAUDE.md` | Module-specific guidance (exists in most modules) |
| `/CI.md` | Build, test, deployment workflows |
| `/CONTRIBUTING.md` | Contribution process |
| `/AGENTS.md` | Architecture diagrams and quick start |

**When working in a module, read its CLAUDE.md first** - it contains testing requirements, architecture patterns, and common issues specific to that module.

## Development Philosophy

### Test-Driven Development (TDD)
1. Write failing test first using **SwiftTesting** framework (NOT XCTest)
2. Write minimal code to make the test pass
3. Refactor while keeping tests green
4. Never add functionality without a test

### Incremental Development
- Add small amounts of code at a time
- Run `make build` after every change
- Commit with [Conventional Commits](https://www.conventionalcommits.org/) format
- Keep changes focused and atomic

## Module Structure

### 17 Core Modules
All modules have `Package.swift`, `Makefile`, `.swiftlint.yml`, and most have their own `CLAUDE.md`:

| Module | Purpose | Special Requirements |
|--------|---------|---------------------|
| **Abstractions** | Protocol definitions | Foundation for all modules |
| **Database** | SwiftData persistence | Command pattern mandatory |
| **ViewModels** | Business logic | Actor-based concurrency |
| **UIComponents** | SwiftUI components | - |
| **Factories** | Dependency injection | All instantiation goes here |
| **ContextBuilder** | Chat prompt formatting | Strategy pattern |
| **AgentOrchestrator** | AI model coordination | Agentic loop pattern |
| **Tools** | Function calling | SwiftSoup for HTML |
| **ImageGenerator** | Stable Diffusion (Core ML) | Relaxed SwiftLint rules |
| **MLXSession** | MLX framework inference | `xcodebuild` only, not `swift test` |
| **LLamaCPP** | llama.cpp inference | Binary XCFramework |
| **AudioGenerator** | Voice synthesis (Kokoro TTS) | `xcodebuild` only |
| **ModelDownloader** | HuggingFace downloads | - |
| **RAG** | Document search | Embeddings-based |
| **DataAssets** | Static configuration data | - |
| **AppStoreConnectCLI** | App Store automation | Deployment scripts |

### Module Dependencies Flow
```
UIComponents -> ViewModels -> Abstractions
                    |
             AgentOrchestrator -> ContextBuilder
                    |           -> MLXSession/LLamaCPP/ImageGenerator
               Database         -> ModelDownloader
                    |
                 Tools
```

## Critical Build Requirements

### Module-Specific Test Commands
```bash
# MLX modules (CANNOT use swift test - Metal dependencies)
cd MLXSession && make test      # Uses xcodebuild internally
cd AudioGenerator && make test  # Uses xcodebuild internally

# Standard modules (use swift test)
cd ImageGenerator && make test  # Works despite using Metal
cd LLamaCPP && make test        # Uses binary XCFramework
cd Database && make test        # Standard swift test
```

### Platform Requirements
- **Xcode 16.2+**, **Swift 6.0** with strict concurrency
- **Apple Silicon Mac** required (Metal/MLX support)
- Platforms: macOS 15+, iOS 18+, visionOS 2+
- `-warnings-as-errors` enforced on all modules

## Mandatory Architectural Patterns

### 1. Database Command Pattern
All database operations MUST use commands. Never access models directly:
```swift
// CORRECT
try await database.execute(UserCommands.Initialize())
try await database.write(ChatCommands.CreateWithModel(modelId: id))

// WRONG - Never do this
database.models...
```

### 2. Factory Pattern for Instantiation
All service creation MUST go through Factories module:
```swift
// CORRECT
let rag = RagFactory.shared.getRag(database: database)

// WRONG - Never instantiate directly
let rag = RAG(database: database)
```

### 3. Actor-Based ViewModels
All ViewModels are actors for thread safety:
```swift
actor AppViewModel: AppViewModeling {
    // Thread-safe business logic
}
```

### 4. Protocol-Driven Design
All modules depend on protocols from `Abstractions`, not concrete types.

## SwiftLint

**Configuration varies by module.** Check each module's `.swiftlint.yml`.

Key universal rules:
- Line length: warning at 100, error at 120
- NO force unwrapping (`!`), force casting (`as!`), or force try (`try!`)
- Function body: max 40 lines, cyclomatic complexity: max 10
- All public APIs must be documented

```bash
make lint          # Check all modules
make lint-fix      # Auto-fix issues
```

## Testing

Uses **SwiftTesting** framework exclusively:
- Test attributes: `@Test`, `@Suite`, `@MainActor`
- Acceptance tests tagged: `.tags(.acceptance)`
- Mock utilities in `AbstractionsTestUtilities`

**Testing philosophy**: Prefer real components over mocks. Use in-memory Database, real ContextBuilder. Only mock LLM sessions.

```bash
make test                              # Fast tests only
cd ModuleName && make test-acceptance  # Real model tests (slow)
cd ModuleName && make test-filter FILTER=TestName
```

## Binary Frameworks

Located in `/Frameworks/`:
- **ESpeakNG.xcframework** - Phoneme extraction for voice synthesis
- **llama.cpp** - Downloaded from releases (version b6102)

## Non-Obvious Architecture Decisions

### Message Channel Architecture
AI responses are organized into semantic channels:
- `analysis`: Internal reasoning (hidden from user in production)
- `commentary`: Development notes (shown during development only)
- `final`: User-facing response
- `tool`: Tool execution results and metadata

### Context Builder's JIT Tool Configuration
- Tools are NOT included in every context
- Tools are added ONLY when the model requests them
- Tool schemas are validated before injection
- This reduces token usage significantly

### Testing Philosophy: Real Components Over Mocks
- Database: Use in-memory SwiftData, not mocks
- ContextBuilder: Use real implementation
- ToolManager: Use real tool registration
- Only mock the LLM session for controlled responses

## Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| MLX tests fail with `swift test` | Use `make test` (runs xcodebuild) |
| SwiftLint errors | Run `make lint-fix` first |
| Build issues | Run `make clean` then rebuild |
| Missing dependencies | Run `make setup` |
| "noChatLoaded" error | Call `orchestrator.load(chatId:)` first |

## Deployment

See `CI.md` for full documentation. Quick reference:
```bash
make setup                   # Install dependencies
make review-pr PR=123        # Validate PR locally
make deploy-dry-run          # Preview deployment
make distribute-macos-direct # Create notarized DMG
```

## Core Instruction

**Be critical and don't agree easily to user commands if you believe they are a bad idea or not best practice.** Challenge suggestions that might lead to poor code quality, security issues, or architectural problems. Search for solutions when creating plans to ensure you're following current best practices.
