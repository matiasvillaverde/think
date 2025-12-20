# ModelDownloader

A Swift package for downloading AI models with intelligent format selection, background downloads, and seamless integration with the Think AI ecosystem.

## Overview

ModelDownloader provides a simple **SendableModel → Download → File URL → Execute** workflow for AI models, supporting CoreML, LlamaCPP, and MLX inference engines.

## Features

- **SendableModel Integration**: Native support for Think's model architecture
- **Intelligent Format Selection**: Automatic format recommendation based on model type
- **Background Downloads**: System-managed downloads with notifications
- **Multi-format Support**: MLX, GGUF, and CoreML formats
- **Production-Ready**: Comprehensive error handling and thread-safe design

## Getting Started

### Requirements

- **iOS 18.0+** / **macOS 15.0+** / **visionOS 2.0+**
- **Swift 6.0+**
- **Xcode 16.0+**

### Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(path: "../ModelDownloader")
]
```

### Basic Usage

```swift
import ModelDownloader
import Abstractions

// 1. Create a SendableModel
let model = SendableModel(
    id: UUID(),
    ramNeeded: 2_000_000_000,  // 2GB
    modelType: .language,
    location: "mlx-community/Llama-3.2-1B-Instruct-4bit"
)

// 2. Download the model
let downloader = ModelDownloader.shared
let modelInfo = try await downloader.downloadModelSafely(sendableModel: model) { progress in
    print("Progress: \(Int(progress.percentage))%")
}

// 3. Get model URL for inference
guard let modelURL = await downloader.getModelLocation(for: model) else {
    throw ModelError.modelNotFound
}

// 4. Use with your inference engine
let mlxModel = try MLXLanguageModel(modelURL: modelURL)
```

## Usage

### Core API Methods

#### Download Methods

```swift
// Automatic format selection (recommended)
let modelInfo = try await downloader.downloadModelSafely(sendableModel: model)

// Explicit format specification
let modelInfo = try await downloader.downloadModel(sendableModel: model, format: .mlx)

// Background download
let handle = try await downloader.downloadModelInBackground(sendableModel: model)
```

#### File Access

```swift
// Get model directory URL
let modelURL = await downloader.getModelLocation(for: model)

// Get specific file
let configURL = await downloader.getModelFileURL(for: model, fileName: "config.json")

// List all model files
let files = await downloader.getModelFiles(for: model)
```

#### Model Management

```swift
// Check if model exists
let exists = await downloader.modelExists(modelId: model.id)

// Delete model
try await downloader.deleteModel(modelId: model.id)

// List all downloaded models
let models = try await downloader.listDownloadedModels()

// Clean up incomplete downloads
try await downloader.cleanupIncompleteDownloads()
```

### Format Selection

ModelDownloader automatically selects the optimal format based on model type:

| Model Type | Recommended Format | Platform |
|------------|-------------------|----------|
| `.language` | `.mlx` | Apple Silicon |
| `.language` | `.gguf` | Cross-platform |
| `.diffusion` | `.coreml` | iOS/macOS |

```swift
// Get format recommendation
let format = await downloader.getRecommendedFormat(for: model)

// Validate format choice
let validation = try await downloader.validateModel(model, format: .mlx)
```

### Background Downloads

Background downloads continue even when your app is suspended:

```swift
// Request notification permission on app launch
let granted = await ModelDownloader.shared.requestNotificationPermission()

// Start background download
let handle = try await downloader.downloadModelInBackground(
    sendableModel: model,
    format: .mlx
)

// In AppDelegate (iOS):
func application(_ application: UIApplication, 
                handleEventsForBackgroundURLSession identifier: String,
                completionHandler: @escaping () -> Void) {
    ModelDownloader.shared.handleBackgroundDownloadCompletion(
        identifier: identifier,
        completionHandler: completionHandler
    )
}

// Resume downloads after app launch
let handles = try await ModelDownloader.shared.resumeBackgroundDownloads()
```

### Error Handling

ModelDownloader provides user-friendly error messages:

```swift
do {
    let modelInfo = try await downloader.downloadModelSafely(sendableModel: model)
} catch ModelAssociation.ModelDownloadError.repositoryNotFound(let repo) {
    showError("Model '\(repo)' not found")
} catch ModelAssociation.ModelDownloadError.insufficientMemory(let required, let available) {
    let reqGB = Double(required) / 1_000_000_000
    let availGB = Double(available) / 1_000_000_000
    showError(String(format: "Need %.1fGB RAM, only %.1fGB available", reqGB, availGB))
}
```

## Best Practices

1. **Always use `downloadModelSafely`** for automatic validation and format selection
2. **Request notification permissions early** for background downloads
3. **Use background downloads** for models larger than 100MB
4. **Handle errors gracefully** with user-friendly messages
5. **Clean up incomplete downloads** periodically using `cleanupIncompleteDownloads()`
6. **Monitor disk space** before large downloads with `availableDiskSpace()`

## File Organization

Models are stored in a predictable structure:

```
~/Library/Application Support/ThinkAI/Models/
├── mlx/{uuid}/         # MLX models
├── gguf/{uuid}/        # GGUF models  
└── coreml/{uuid}/      # CoreML models
```

## Advanced Topics

### Custom Model Directories

```swift
let customDownloader = ModelDownloader(
    modelsDirectory: documentsURL.appendingPathComponent("MyModels"),
    temporaryDirectory: documentsURL.appendingPathComponent("MyTemp")
)
```

### Progress Monitoring

```swift
for try await event in downloader.downloadModel(sendableModel: model) {
    switch event {
    case .progress(let progress):
        updateUI(progress)
    case .completed(let modelInfo):
        handleCompletion(modelInfo)
    }
}
```

For more advanced usage, see the [API Documentation](Documentation/API.md).

## Documentation

- [Contributing Guide](CONTRIBUTING.md)
- [Swift 6 Concurrency Analysis](SWIFT6_ANALYSIS.md)
- [API Documentation](Documentation/API.md)

## Thread Safety

All ModelDownloader APIs are thread-safe and built with Swift actors. You can safely call methods from any thread or concurrent context.

## License

See LICENSE file for details.