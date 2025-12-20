# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## MLXSession Module Overview

MLXSession provides MLX framework integration for local AI model execution on Apple Silicon hardware. It serves as the primary interface for running large language models using Apple's Metal Performance Shaders.

## Critical Build and Test Requirements

### ⚠️ IMPORTANT: Special Testing Requirements

**This module requires `xcodebuild` instead of `swift test` due to MLX Metal dependencies.**

```bash
# Build (standard swift build works)
make build

# Testing - MUST use xcodebuild with workspace context
make test                    # Runs from parent with xcodebuild
make test-acceptance         # Test with real models
make test-filter FILTER=name # Run specific test

# What actually runs:
cd .. && xcodebuild test \
  -workspace Think.xcworkspace \
  -scheme MLXSession \
  -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1
```

**Why these requirements exist:**
- MLX framework requires Metal GPU support
- Tests must run serially to avoid GPU resource conflicts
- Workspace context needed for proper framework linking
- Must run on real hardware (not simulators)

## Architecture

### Core Components

```
MLXSession (Actor) → LLMSession Protocol
    ├── ModelContainer (thread-safe model access)
    ├── StopFlag (generation cancellation)
    ├── Registries (model types, configs, adapters)
    └── MLXLLM/ (16+ model architectures)
         ├── Llama, Llama3
         ├── Phi, Phi3, PhiMoE
         ├── Gemma, Gemma2
         ├── Qwen2, Qwen3
         └── Bitnet, SmolLM3, etc.
```

### Key Design Patterns

1. **Actor-based concurrency**: Main `MLXSession` is an actor for thread safety
2. **ModelContainer pattern**: Ensures single-threaded GPU access
3. **Registry pattern**: Type-safe model architecture registration
4. **Factory pattern**: Clean instantiation via `MLXSessionFactory`

## Development Commands

```bash
# Module-specific commands
make build              # Build module
make test              # Run tests (uses xcodebuild)
make test-acceptance   # Test with real models (slow!)
make test-filter FILTER=TestName  # Run specific test
make lint              # Check SwiftLint (relaxed rules)
make quality          # lint + build + test
```

## Testing Patterns

### Test Structure
```swift
@Suite("Model Tests")
struct ModelTest {
    let baseTest = BaseModelTest()  // Common utilities
    
    @Test("Generate text")
    func testGeneration() async throws {
        // 1. Get model from bundle
        // 2. Verify files exist
        // 3. Create MLXSession
        // 4. Preload model
        // 5. Stream generation
        // 6. Validate results
    }
}
```

### Important Testing Notes
- Uses SwiftTesting framework (`@Test`, `@Suite`, `#expect`)
- Tests run serially (GPU resource constraint)
- Each architecture has dedicated test target
- Model files included in `Resources/` directories

## Model Loading Flow

1. **Download (0-30%)**: HuggingFace Hub integration
2. **Config (30-50%)**: JSON parsing for architecture
3. **Weights (50-80%)**: SafeTensor loading with quantization
4. **Tokenizer (80-100%)**: Swift-transformers setup

## Hardware Requirements

- **Apple Silicon Mac required** (M1/M2/M3)
- **Metal support mandatory** for GPU acceleration
- **Memory requirements**: 
  - 1B models: ~2GB RAM
  - 3B models: ~4GB RAM
  - 7B models: ~8GB RAM
  - 13B models: ~16GB RAM

## SwiftLint Configuration

This module has **relaxed linting rules** due to ML complexity:
- `Common/` and `MLXLLM/` directories excluded
- Only `MLXSession.swift` and `MLXSessionFactory.swift` are linted
- Many rules disabled for complex ML implementations

## Integration with Think

### Protocol Compliance
Implements `LLMSession` from Abstractions module:
```swift
public protocol LLMSession: Sendable {
    func preloadModel(from url: URL, progress: ((Double) -> Void)?) async throws
    func generate(prompt: String, streaming: ((String) -> Void)?) async throws -> GenerateResult
}
```

### Usage by AgentOrchestrator
```swift
// Created via factory
let session = MLXSessionFactory.create()

// Used for model inference
try await session.preloadModel(from: modelURL)
let result = try await session.generate(prompt: prompt)
```

## Common Development Tasks

### Adding New Model Architecture

1. Create configuration in `MLXLLM/Models/NewModel.swift`
2. Register in `MLXSession+Registries.swift`
3. Add test target in `Package.swift`
4. Create test file in `Tests/NewModelTests/`
5. Include test model in `Resources/`

### Debugging Model Loading

```swift
// Enable detailed logging
os_log(.debug, log: .model, "Loading phase: %{public}@", phase)

// Check model files
ModelFileManager.verifyModelFiles(at: modelURL)

// Monitor memory usage
MLXArray memory tracking in ModelContainer
```

### Handling GPU Resources

```swift
// Always use ModelContainer for thread safety
modelContainer.model { model in
    // GPU operations here
    let result = model.generate(...)
    // Must eval() MLXArrays before returning
    MLX.eval(result)
}
```

## Important Gotchas

1. **MLXArrays must be evaluated** before crossing actor boundaries
2. **Only one model** can use GPU at a time (serial execution)
3. **Models are loaded lazily** - preload before first generation
4. **Offline fallback** works only if model already cached
5. **Quantization affects quality** - use appropriate bit depth

## Dependencies

### MLX Framework Components
- `MLX`: Core framework
- `MLXFast`: Performance optimizations
- `MLXNN`: Neural network ops
- `MLXOptimizers`: Training support
- `MLXRandom`: Random generation
- `MLXLinalg`: Linear algebra

### External Dependencies
- `swift-transformers` (0.1.22): HuggingFace integration
- `Abstractions`: Protocol definitions
- `Hub`: Model downloading

## Performance Optimization

### Best Practices
1. Preload models before generation
2. Use appropriate quantization (4-bit for memory, 16-bit for quality)
3. Stream responses for better UX
4. Cancel long generations with StopFlag
5. Monitor memory with Activity Monitor

### Benchmarking
```bash
# Run performance tests
make test-filter FILTER=PerformanceTest

# Profile with Instruments
xcrun xctrace record --template "Metal System Trace"
```

Remember: MLXSession is the most complex module in Think due to its Metal/GPU requirements and ML framework integration. Always test on real hardware and be mindful of GPU resource constraints.