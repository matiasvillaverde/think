# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Module Overview

The ImageGenerator module implements Stable Diffusion image generation using Core ML for efficient on-device AI image synthesis. This module is part of the larger Think multi-platform AI application and integrates with the AgentOrchestrator for model coordination.

## Architecture

### Core Components

**Image Generation Pipeline**
- `ImageGenerator`: Main actor-based interface implementing `ImageGenerating` protocol
- `StableDiffusionPipeline`: Core ML pipeline for SD 1.5/2.0/2.1 models
- `StableDiffusionXLPipeline`: Specialized pipeline for SDXL models
- Implements async streaming for progress updates during generation

**Pipeline Components**
- `TextEncoder`: CLIP text encoding for prompt processing
- `Unet`: Denoising network for latent space manipulation
- `VAEDecoder`: Converts latents to images
- `VAEEncoder`: Converts images to latents (for img2img)
- `ControlNet`: Optional control network for guided generation
- `SafetyChecker`: Optional NSFW content filtering

**Schedulers** (Sampling algorithms)
- `DPMSolverMultistepScheduler`: DPM-Solver++ for efficient sampling
- `PNDMScheduler`: Pseudo-linear multi-step method
- `DiscreteFlowScheduler`: Rectified flow for transformer models

**Resource Management**
- `ManagedMLModel`: Wrapper for Core ML model lifecycle
- `ResourceManaging`: Protocol for memory-efficient model loading/unloading
- Supports on-demand model loading to reduce memory footprint

## Development Commands

### Building
```bash
# Build the module
make build              # Includes linting

# Build with CI strictness
make build-ci          # Warnings as errors
```

### Testing
```bash
# Fast unit tests only (recommended for development)
make test

# Run specific test
make test-filter FILTER=ImageGeneratorBasicTests

# Acceptance tests with real Core ML models (slow!)
make test-acceptance

# Test Metal Performance Shaders
make test-metal

# iOS simulator testing
make test-ios
```

### Code Quality
```bash
# Run linting (note: relaxed rules for this module)
make lint

# Auto-fix linting issues
make lint-fix

# Full quality check suite
make quality           # lint + deadcode + duplication + complexity

# Find dead code
make deadcode

# Check code duplication
make duplication
```

## Testing Approach

This module uses SwiftTesting framework exclusively:
- Test files in `Tests/ImageGeneratorTests/`
- Mock implementations for fast unit tests
- Acceptance tests with real models tagged with `.tags(.acceptance)`
- All tests use `@Test` and `@Suite` attributes (NOT XCTest)

### Test Organization
- `ImageGeneratorBasicTests`: Core functionality tests
- `ImageGeneratorProgressTests`: Progress streaming tests
- `ImageGeneratorMetricsTests`: Performance metrics collection
- `ImageGeneratorAcceptanceTests`: Real model integration tests

## SwiftLint Configuration

**IMPORTANT**: This module has relaxed SwiftLint rules due to the complexity of the Stable Diffusion implementation. Many strict rules are disabled to accommodate:
- Domain-specific naming in image processing algorithms
- Numeric constants required for ML computations
- Complex mathematical operations in schedulers

Key disabled rules include:
- `identifier_name`: Domain-specific names allowed
- `no_magic_numbers`: Required for image processing
- `force_unwrapping`: Some Core ML operations require it
- `explicit_type_interface`: Would require thousands of changes

When working in this module, focus on:
- Maintaining existing code style consistency
- Following Swift best practices
- Ensuring thread safety with actors
- Proper error handling

## Platform Requirements

- **macOS 15.0+, iOS 18.0+, visionOS 2.0+**
- **Metal support required** for optimal performance
- **Neural Engine** utilized when available
- **Memory**: 4GB+ recommended for SDXL models

## Model Support

Supports standard Stable Diffusion Core ML models:
- SD 1.5, 2.0, 2.1 (512x512)
- SDXL (1024x1024)
- ControlNet models for guided generation
- Custom fine-tuned models from HuggingFace

Model files required:
- `TextEncoder.mlmodelc` or `TextEncoder.mlpackage`
- `Unet.mlmodelc` or `Unet.mlpackage`
- `VAEDecoder.mlmodelc` or `VAEDecoder.mlpackage`
- `VAEEncoder.mlmodelc` (optional, for img2img)
- `ControlNet.mlmodelc` (optional, for controlled generation)

## Integration with Think

This module integrates with:
- `AgentOrchestrator`: Coordinates image generation requests
- `ModelDownloader`: Downloads models from HuggingFace
- `Database`: Stores generation history and metadata
- `Abstractions`: Implements `ImageGenerating` protocol

## Performance Considerations

- Models are loaded on-demand to manage memory
- Supports batch generation for efficiency
- Progress streaming prevents UI blocking
- Metrics collection for performance monitoring
- Metal Performance Shaders for GPU acceleration

## Common Tasks

### Adding New Scheduler
1. Create new scheduler implementing `Scheduler` protocol
2. Add to `StableDiffusionScheduler` enum
3. Implement stepping algorithm following paper specifications
4. Add tests comparing outputs to reference implementation

### Modifying Pipeline
1. Changes to `StableDiffusionPipeline` affect all model variants
2. SDXL-specific changes go in `StableDiffusionXLPipeline`
3. Maintain backward compatibility with existing models
4. Test with both SD and SDXL models

### Debugging Generation Issues
1. Enable verbose logging in `ImageGenerator`
2. Check `ImageMetricsCollector` for performance bottlenecks
3. Verify model files are complete and valid
4. Monitor memory usage during generation
5. Test with reference prompt: "a photo of an astronaut riding a horse on mars"

## Error Handling

The module uses `ImageGeneratorError` (formerly `PipelineError`) with cases:
- `missingInputs`: Required model components not found
- `invalidConfiguration`: Invalid generation parameters
- `modelLoadingFailed`: Core ML model loading error
- `generationFailed`: Runtime generation error
- `cancelled`: Generation was cancelled by user

Always handle errors explicitly and provide meaningful feedback to users.