# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Module Purpose

DataAssets is a centralized repository for hardcoded data, configurations, and metadata. It contains no business logic - only static data and simple accessor methods. This module was created to extract data that was previously scattered across other modules (particularly Abstractions).

## Architecture

### Core Components

1. **RecommendedModels**: Curated AI model lists organized by device memory tiers
   - 82 language models across 6 memory tiers (4GB, 8GB, 16GB, 32GB, 64GB, 128GB+)
   - 10 image generation models optimized for Apple devices
   - Memory-based filtering system with tier midpoint logic

2. **SystemInstruction**: AI assistant personality prompts
   - 25+ predefined personalities (code reviewer, storyteller, legal advisor, etc.)
   - Localization support via String(localized:)
   - Custom instruction support via `.custom(String)` case
   - Date placeholder injection with `{DATE}` token

3. **DataAssets**: Module entry point with version information

### Memory Tier System

Models are organized by memory requirements with inclusive filtering:
- Higher tiers include all models from lower tiers
- Uses midpoint calculation for non-exact memory values (e.g., 6GB → 8GB tier)
- Special handling for always-include models regardless of tier
- `RecommendationType` enum for fast vs complex task categorization

## Development Commands

```bash
# Core development workflow
make test         # Run all tests
make build        # Build module  
make lint         # Run SwiftLint (strict mode)
make lint-fix     # Auto-fix linting issues
make all          # Run lint → build → test

# Clean build artifacts
make clean
```

## Testing

Uses SwiftTesting framework (NOT XCTest) with comprehensive coverage:
- Memory tier classification tests
- Model filtering by available memory
- Edge case handling for device boundaries
- System instruction retrieval tests

Test patterns:
```swift
@Suite("DataAssets Module Tests")
@Test("Should return memory tier for exact memory values")
```

## SwiftLint Configuration

This module has a highly permissive SwiftLint configuration since it primarily contains static data:
- Allows long lines, large files, and magic numbers
- Disables most style rules while keeping safety rules
- Uses `--strict` flag but with many disabled rules specific to data modules

## Adding New Data

### Adding Language Models

1. Determine appropriate memory tier based on model requirements
2. Add to corresponding tier array in `RecommendedModels.swift`
3. Consider if model should be in `alwaysIncludeModels` set
4. Update tests if adding new tier or edge cases

### Adding System Instructions

1. Add new case to `SystemInstruction` enum
2. Implement localized prompt in `prompt` computed property
3. Include appropriate behavioral instructions and disclaimers
4. Consider date placeholder injection if time-sensitive

### Adding Image Models

1. Add to `defaultImageModels` array
2. Ensure model is CoreML-compatible
3. Consider device optimization requirements

## Integration Points

- **UIComponents**: Uses RecommendedModels for model selection UI
- **Database**: Uses SystemInstruction for personality configurations  
- **ViewModels**: Accesses system instructions for chat configurations
- No external dependencies - completely self-contained

## Key Implementation Details

### Memory Calculation
```swift
// Tier assignment uses midpoint logic
let midpoints = [6, 12, 24, 48, 96]  // GB values
// 6GB memory → 8GB tier, 12GB → 16GB tier, etc.
```

### Always-Include Models
Four models are included regardless of memory tier:
- gemma-3-1b-it-qat-4bit
- Qwen3-0.6B-4bit  
- DeepSeek-R1-Distill-Qwen-1.5B-4bit
- SmolLM-1.7B-Instruct-4bit

### Type Safety
- All data structures use enums for exhaustive case handling
- Implements Codable, CaseIterable, Sendable, Hashable protocols
- Prefers value types (structs) over reference types

## Module Conventions

- Data arrays are static constants, not computed properties
- Use descriptive names for model identifiers
- Group related models together with comments
- Keep system instructions focused and behavioral
- No business logic - only data and simple accessors