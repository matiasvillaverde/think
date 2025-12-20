# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## AudioGenerator Module Overview

The AudioGenerator module provides voice synthesis capabilities using MLX/Kokoro TTS, a neural text-to-speech system that converts text into natural-sounding speech.

## Key Commands

### Building and Testing
```bash
# Build the module
make build              # Builds with linting
make build-ci           # Builds with warnings as errors

# Run tests (requires xcodebuild due to MLX Metal dependencies)
make test               # Run tests on macOS (default)
make test-macos         # Explicitly run macOS tests
make test-ios           # Run tests on iOS simulator

# Run specific tests
make test-filter FILTER=AudioEngineTests  # Run tests matching pattern

# Code quality
make lint               # Run SwiftLint with strict enforcement
make lint-fix           # Auto-fix SwiftLint issues
make quality            # Run all quality checks (lint + deadcode + duplication)
```

### Important Testing Requirements
- **MUST use xcodebuild**: Tests require `xcodebuild` with workspace context due to MLX Metal dependencies
- Tests run from parent directory: `cd .. && xcodebuild test -workspace Think.xcworkspace`
- Tests require real hardware with Metal support (no simulators for MLX)
- All tests run serially to avoid GPU conflicts

## Architecture

### Core Components

#### AudioEngine (Actor)
- Main entry point: `AudioEngine.swift`
- Thread-safe actor implementing `AudioGenerating` protocol
- Lazy initialization of resources for performance
- Handles both TTS generation and speech recognition
- Manages AVAudioEngine and audio session configuration

#### Kokoro TTS Pipeline
- **KokoroTTS**: Main TTS class orchestrating the pipeline
- **Components**:
  - **CustomAlbert**: BERT-based text encoder for semantic understanding
  - **ESpeakNGEngine**: Phoneme extraction using eSpeak-NG
  - **TextEncoder**: Encodes phonemes and text features
  - **DurationEncoder**: Predicts speech timing
  - **ProsodyPredictor**: Generates prosody features (pitch, stress)
  - **Decoder**: Generates mel-spectrograms from features
  - **Generator**: Neural vocoder converting spectrograms to audio

#### Voice Support
- Three built-in voices: `afHeart`, `bmGeorge`, `zfXiaoni`
- Voice data loaded from JSON configuration files
- Model weights in `kokoro-v1_0.safetensors` (MLX format)

### Key Technical Details

#### MLX Framework Integration
- Uses MLX Swift for Metal-accelerated neural network inference
- Custom implementations of:
  - LSTM layers for sequence modeling
  - AdaIN (Adaptive Instance Normalization) for style transfer
  - Reflection padding for convolutions
  - Custom STFT implementation for audio processing

#### Audio Processing
- Sample rate: 24kHz
- Hop size: 256 samples
- FFT size: 1024
- Window: Hann window
- Output format: Float32 PCM audio

#### Phoneme Processing
- ESpeakNG binary framework for text-to-phoneme conversion
- Supports multiple languages (currently en-US, en-GB)
- Custom tokenizer for phoneme sequence encoding

### SwiftLint Configuration

The module has specific SwiftLint exceptions due to ML/audio domain requirements:
- `identifier_name`: Allows domain-specific names (F0, i, x)
- `type_body_length`: KokoroTTS requires longer class for ML implementation
- `no_magic_numbers`: Common in audio processing (sample rates, FFT sizes)
- Force unwrapping disabled in specific files with `// swiftlint:disable force_unwrapping`

### Testing Strategy

#### Unit Tests
- `AudioGenerationTests`: Core TTS functionality
- `SayMethodIntegrationTests`: High-level API testing
- Performance tests for generation speed
- Lazy initialization tests for resource management

#### Test Patterns
```swift
@Suite("Audio Generation Tests", .serialized)  // Tests run serially
@Test("Generate audio for valid text")
func testGenerateAudioValidText() async throws {
    // Tests use exact audio length expectations
    #expect(audioData.count == 37_800)  // Specific to "Hello world"
}
```

### Common Development Tasks

#### Adding New Voices
1. Create voice JSON configuration in Resources/
2. Update `TTSVoice` enum in KokoroTTS.swift
3. Add voice loading logic in VoiceLoader.swift
4. Test with specific phoneme patterns

#### Debugging Audio Issues
1. Check BenchmarkTimer logs for performance bottlenecks
2. Verify Metal device availability
3. Monitor memory usage during model loading
4. Use AudioUtils for format conversions

#### Performance Optimization
- Models are loaded lazily on first use
- Weights are cached after loading
- Audio engine initialized only when needed
- GPU memory managed via MLX eval() calls

### Dependencies

- **MLX Swift**: Neural network inference on Metal
- **ESpeakNG.xcframework**: Phoneme extraction (binary framework)
- **AVFoundation**: Audio playback and recording
- **Abstractions**: Protocol definitions from parent project

### Module-Specific Gotchas

1. **Metal Required**: Module will not work on non-Metal devices
2. **Memory Usage**: Model loading requires ~500MB RAM
3. **First Run**: Initial generation slower due to model loading
4. **Thread Safety**: All public methods are actor-isolated
5. **Test Isolation**: Tests must run serially due to GPU resource sharing