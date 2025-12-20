# Think AI

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20macOS%20%7C%20visionOS-blue.svg)](https://developer.apple.com)

A native Apple ecosystem AI application providing intelligent conversational experiences across iOS, macOS, and visionOS platforms with local AI model execution.

## Overview

Think is a multi-platform AI assistant built with SwiftUI and Apple's MLX framework, enabling sophisticated on-device AI interactions without requiring cloud processing.

### Key Features

- **🍎 Native Apple Ecosystem**: iOS 18+, macOS 15+, visionOS 2+
- **🧠 Local AI Processing**: On-device model execution via MLX framework
- **🎭 20+ AI Personalities**: Specialized personas for various use cases
- **🌍 40+ Languages**: Comprehensive internationalization
- **🎙️ Voice Synthesis**: Text-to-speech with ESpeakNG
- **📄 Document Search (RAG)**: Retrieval-augmented generation
- **☁️ iCloud Sync**: SwiftData persistence with cloud synchronization

## Architecture

### Design Principles

- **MVVM with Swift Actors**: Thread-safe ViewModels using Swift's actor model
- **Protocol-Driven Design**: Mockable interfaces for testing and flexibility
- **Command Pattern**: Centralized database operations
- **Modular Swift Packages**: Clean separation of concerns

### Package Structure

```
Think/
├── Abstractions/       # Core protocols and interfaces
├── Database/          # SwiftData models and persistence
├── ViewModels/        # Business logic implementations
├── UIComponents/      # Reusable SwiftUI components
├── AgentOrchestrator/ # AI model coordination and orchestration
├── MLXSession/        # MLX framework integration for local AI
├── LLamaCPP/          # Llama.cpp integration for efficient inference
├── ModelDownloader/   # AI model downloading and management
├── AudioGenerator/    # Voice synthesis capabilities
├── ImageGenerator/    # Stable Diffusion image generation
├── Context/          # AI context management
├── RAG/              # Document search implementation
├── Factories/        # Dependency injection and wiring
└── Think/        # Main app target
```

### Data Flow

```
SwiftUI Views → ViewModels (Actors) → Database Commands → SwiftData
                    ↓
              AgentOrchestrator → MLXSession → MLX Framework
                    ↓           ImageGenerator → Core ML
                    ↓           LLamaCPP → llama.cpp
                    ↓
               ModelDownloader → HuggingFace Models
```

### Key Architecture Decisions

1. **Abstractions First**: All modules depend on protocol interfaces, not concrete implementations
2. **Actor-Based ViewModels**: Ensures thread safety for concurrent operations
3. **Command Pattern for Database**: All database operations go through command objects for consistency
4. **Factories for Wiring**: Single source of truth for dependency injection

## Requirements

- **Xcode**: 16.2 or later
- **Swift**: 6.0
- **Hardware**: Apple Silicon Mac (for development)
- **Platforms**:
  - macOS 15.0+
  - iOS 18.0+
  - visionOS 2.0+

## Quick Start

```bash
# Clone and setup
git clone https://github.com/your-org/think.git
cd think
make setup

# Build and run
make build
make run
```

**Note**: Replace `your-org` with the actual GitHub organization or username where this repository is hosted.

For detailed setup, CI/CD workflows, and deployment, see [CI.md](CI.md).

## Development

### Test-Driven Development

This project follows strict TDD practices using SwiftTesting framework (not XCTest).

```bash
# Test all modules
make test-all

# Test specific module
cd ViewModels && make test
```

### Project Navigation

When exploring the codebase:

1. **Start with Abstractions**: Understand the protocol interfaces
2. **Check Factories**: See how dependencies are wired
3. **Module Tests**: Each module has comprehensive tests showing usage
4. **Use CLAUDE.md**: Contains detailed AI-specific instructions

## AI Model Integration

### Supported Model Types

- **LLM**: Text generation via MLXSession and LLamaCPP
- **Diffusion**: Image generation via ImageGenerator (Core ML)
- **Voice**: Text-to-speech synthesis via AudioGenerator

### Model Management

Models are managed through multiple backend systems:
- `AgentOrchestrator`: Coordinates inference across all backends
- `MLXSession`: MLX framework for efficient GPU inference
- `LLamaCPP`: CPU/GPU inference using llama.cpp
- `ImageGenerator`: Core ML Stable Diffusion models
- `ModelDownloader`: Downloads and caches models from HuggingFace

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for:
- Development process
- Commit conventions
- Code style guidelines
- Pull request process

## Documentation

- **[CI.md](CI.md)**: Complete CI/CD documentation
- **[CONTRIBUTING.md](CONTRIBUTING.md)**: Contribution guidelines
- **[CLAUDE.md](CLAUDE.md)**: AI assistant development instructions
- **[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)**: Third-party licenses and attributions

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

### Third-Party Software

Think uses various third-party tools and frameworks. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for complete attribution and license information.

**Important**: When downloading AI models from HuggingFace Hub, you are responsible for complying with each model's individual license terms.

---

Built with ❤️ using SwiftUI and MLX Framework
