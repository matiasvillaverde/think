# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Module Overview

The LLamaCPP module provides Swift bindings to llama.cpp for efficient CPU/GPU inference of Large Language Models (LLMs). It integrates with the Think AI platform through the `LLMSession` protocol from the Abstractions module.

## Architecture

### Core Components

- **LlamaCPPFactory**: Public entry point and factory for creating LLM sessions
- **LlamaCPPSession**: Actor-based implementation of the LLMSession protocol (internal)
- **LlamaCPPModel**: Wrapper for llama.cpp model loading and management
- **LlamaCPPContext**: Manages llama.cpp context and batch processing
- **LlamaCPPGenerator**: Handles token generation and sampling
- **LlamaCPPStreamHandler**: Manages streaming output with stop sequence detection
- **LlamaCPPTokenizer**: Handles text tokenization using llama.cpp

### Design Patterns

The module follows strict encapsulation:
- Only `LlamaCPPFactory` is public
- All implementation details are internal
- Actor-based design for thread safety
- Stream-based API for text generation

## Development Commands

### Build and Test
```bash
# From LLamaCPP directory
make build              # Build with linting
make test              # Run fast tests
make lint              # Check SwiftLint violations
make lint-fix          # Auto-fix linting issues
make quality           # Run all quality checks
```

### Running Specific Tests
```bash
# Standard swift test works (unlike MLX modules)
swift test --filter testName            # Run specific test
swift test --filter LlamaCPPErrorHandling  # Run test suite
```

### Code Quality
```bash
make deadcode          # Find unused code
make duplication       # Check for code duplication
```

## Testing Strategy

### Test Organization
- **Unit Tests**: Fast tests with small test models (Qwen3-0.6B-UD-IQ1_S.gguf)
- **Acceptance Tests**: Tests with higher quality models (Qwen3-0.6B-BF16.gguf)
- Uses SwiftTesting framework (@Test, @Suite) NOT XCTest

### Test Models
Test models are included in `Tests/LLamaCPPTests/Resources/`:
- **Qwen3-0.6B-UD-IQ1_S.gguf**: Ultra-quantized for fast unit tests
- **Qwen3-0.6B-BF16.gguf**: Higher quality for acceptance tests

### Key Test Suites
- **LlamaCPPIntegrationTests**: End-to-end protocol compliance
- **LlamaCPPErrorHandlingTests**: Error paths and edge cases
- **LlamaCPPStreamingTests**: Streaming behavior
- **LlamaCPPMemoryManagementTests**: Resource cleanup
- **LlamaCPPPositionTrackingTests**: Token position tracking
- **LlamaCPPStopSequenceTests**: Stop sequence detection

## SwiftLint Configuration

The module enforces VERY strict linting with specific limits:
- Line length: 110 warning, 120 error
- Function body: 20 warning, 30 error
- Type body: 250 warning, 300 error
- Cyclomatic complexity: 8 max
- All opt-in rules enabled except:
  - `contrasted_opening_brace`
  - `type_contents_order`
  - `redundant_type_annotation`
  - `extension_access_modifier`

## llama.cpp Integration

### Binary Framework
The module uses a pre-compiled XCFramework from llama.cpp releases:
- URL: https://github.com/ggml-org/llama.cpp/releases
- Version: b6102
- Supports: macOS, iOS, visionOS, tvOS platforms
- Architectures: arm64, x86_64

### Platform Configuration
The module auto-detects optimal settings:
- GPU layers automatically configured
- Metal support on Apple Silicon
- CPU fallback for simulators
- Split mode configuration for multi-GPU

### Key Integration Points
```swift
import llama  // Direct import of C API

// Model loading
llama_model_load_from_file(path, params)

// Context creation
llama_context_new_with_model(model, contextParams)

// Token generation
llama_get_logits(context)
llama_sampler_sample(sampler, context, -1)
```

## Error Handling

The module uses the `LLMError` enum from Abstractions:
- `.modelNotFound`: Model file doesn't exist
- `.configurationError`: Invalid configuration
- `.generationFailed`: Generation errors
- `.timeout`: Generation timeout

## Performance Considerations

### Batch Processing
- Default batch size: 512 tokens
- Adjustable via `ComputeConfigurationExtended`
- Batch optimization for throughput

### Memory Management
- Automatic cleanup via deinit
- Proper ordering: context → model → backend
- Thread-safe resource management

### Instrumentation
- SignpostInstrumentation for performance tracking
- MetricsCollector for generation statistics
- Debug logging in DEBUG builds only

## Common Tasks

### Adding New Sampling Parameters
1. Update `SamplerParameters` in Abstractions
2. Map parameters in `LlamaCPPGenerator.createSampler()`
3. Add tests for new parameters

### Debugging Generation Issues
1. Enable debug logging: Build in DEBUG configuration
2. Check SignpostInstrumentation logs
3. Verify model loading with `Logger.logModelParameters()`

### Updating llama.cpp Version
1. Download new XCFramework from llama.cpp releases
2. Update URL and checksum in Package.swift
3. Test with existing test models
4. Update any API changes

## Thread Safety

The module is fully thread-safe through:
- Actor isolation for `LlamaCPPSession`
- Internal state management within actor
- Atomic stop flag for cancellation
- No shared mutable state

## Integration with Think

The module integrates through:
- `LLMSession` protocol implementation
- `ProviderConfiguration` for model setup
- `LLMInput` for generation parameters
- `LLMStreamChunk` for streaming output
- Factory pattern via `Factories` module