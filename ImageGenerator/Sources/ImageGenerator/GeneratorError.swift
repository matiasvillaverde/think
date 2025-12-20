import Foundation
import CoreML

// MARK: - Main Error Type

/// Comprehensive error type for the ImageGenerator module using Swift's best practices
public enum ImageGeneratorError: Error {
    // Model Loading Errors
    case modelNotLoaded
    case modelNotFound(modelName: String)
    case modelLoadingFailed(modelName: String, underlyingError: Error)

    // Tokenizer Errors
    case vocabularyReadFailed(url: URL, underlyingError: Error)
    case tokenizationFailed(text: String, reason: String)

    // ML Model Execution Errors
    case modelExecutionFailed(modelType: ModelType, underlyingError: Error)
    case featureProviderCreationFailed(reason: String, underlyingError: Error)

    // Image Processing Errors
    case imageDecodingFailed(reason: String)
    case imageEncodingFailed(underlyingError: Error)
    case invalidImageDimensions(expected: CGSize, actual: CGSize)

    // Pipeline Errors
    case missingUnetInputs
    case startingImageProvidedWithoutEncoder
    case startingText2ImgWithoutTextEncoder
    case unsupportedOSVersion(required: String, current: String)
    case errorCreatingPreview(underlyingError: Error)

    // Safety Check Errors
    case safetyCheckFailed(reason: String)
    case safetyCheckerNotAvailable

    // Configuration Errors
    case invalidConfiguration(reason: String)
    case invalidSchedulerConfiguration(reason: String)

    // File I/O Errors
    case fileReadError(path: String, underlyingError: Error)
    case invalidFileFormat(expected: String, actual: String)
}

// MARK: - Model Type

public enum ModelType: String, CustomStringConvertible, Sendable {
    case textEncoder = "Text Encoder"
    case textEncoderXL = "Text Encoder XL"
    case unet = "UNet"
    case decoder = "VAE Decoder"
    case encoder = "VAE Encoder"
    case controlNet = "ControlNet"
    case safetyChecker = "Safety Checker"

    public var description: String { rawValue }
}

// MARK: - LocalizedError Conformance

extension ImageGeneratorError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "No model is loaded. Please load a model first."

        case .modelNotFound(let modelName):
            return "Model '\(modelName)' not found. Please download the model first."

        case .modelLoadingFailed(let modelName, let error):
            return "Failed to load model '\(modelName)': \(error.localizedDescription)"

        case .vocabularyReadFailed(let url, let error):
            return "Failed to read vocabulary from '\(url.lastPathComponent)': \(error.localizedDescription)"

        case .tokenizationFailed(let text, let reason):
            let preview = String(text.prefix(50))
            return "Failed to tokenize text '\(preview)...': \(reason)"

        case .modelExecutionFailed(let modelType, let error):
            return "Failed to execute \(modelType) model: \(error.localizedDescription)"

        case .featureProviderCreationFailed(let reason, let error):
            return "Failed to create feature provider (\(reason)): \(error.localizedDescription)"

        case .imageDecodingFailed(let reason):
            return "Failed to decode image: \(reason)"

        case .imageEncodingFailed(let error):
            return "Failed to encode image: \(error.localizedDescription)"

        case .invalidImageDimensions(let expected, let actual):
            return "Invalid image dimensions. Expected \(expected), got \(actual)"

        case .missingUnetInputs:
            return "Required UNet inputs are missing"

        case .startingImageProvidedWithoutEncoder:
            return "Starting image provided but encoder model is not available"

        case .startingText2ImgWithoutTextEncoder:
            return "Text-to-image generation requires a text encoder model"

        case .unsupportedOSVersion(let required, let current):
            return "This feature requires \(required) or later. Current version: \(current)"

        case .errorCreatingPreview(let error):
            return "Failed to create preview: \(error.localizedDescription)"

        case .safetyCheckFailed(let reason):
            return "Safety check failed: \(reason)"

        case .safetyCheckerNotAvailable:
            return "Safety checker model is not available"

        case .invalidConfiguration(let reason):
            return "Invalid configuration: \(reason)"

        case .invalidSchedulerConfiguration(let reason):
            return "Invalid scheduler configuration: \(reason)"

        case .fileReadError(let path, let error):
            return "Failed to read file at '\(path)': \(error.localizedDescription)"

        case .invalidFileFormat(let expected, let actual):
            return "Invalid file format. Expected \(expected), got \(actual)"
        }
    }

    public var failureReason: String? {
        switch self {
        case .modelLoadingFailed(_, let error),
             .vocabularyReadFailed(_, let error),
             .modelExecutionFailed(_, let error),
             .featureProviderCreationFailed(_, let error),
             .imageEncodingFailed(let error),
             .errorCreatingPreview(let error),
             .fileReadError(_, let error):
            return (error as NSError).localizedFailureReason

        default:
            return nil
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .modelNotLoaded, .modelNotFound:
            return "Download and load the required model before attempting this operation."

        case .unsupportedOSVersion(let required, _):
            return "Update your operating system to \(required) or later."

        case .startingImageProvidedWithoutEncoder:
            return "Load a model that includes an encoder component for image-to-image generation."

        case .invalidImageDimensions:
            return "Ensure the input image has the correct dimensions for the model."

        case .safetyCheckFailed:
            return "Try generating different content or disable safety checking if appropriate."

        default:
            return nil
        }
    }
}

// MARK: - Custom Debug Description

extension ImageGeneratorError: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .modelLoadingFailed(let model, let error):
            return "ImageGeneratorError.modelLoadingFailed(model: \"\(model)\", error: \(error))"

        case .modelExecutionFailed(let type, let error):
            return "ImageGeneratorError.modelExecutionFailed(type: .\(type), error: \(error))"

        default:
            return "ImageGeneratorError.\(self)"
        }
    }
}

// MARK: - Error Code Support

extension ImageGeneratorError {
    public var code: Int {
        switch self {
        case .modelNotLoaded: return 1001
        case .modelNotFound: return 1002
        case .modelLoadingFailed: return 1003
        case .vocabularyReadFailed: return 2001
        case .tokenizationFailed: return 2002
        case .modelExecutionFailed: return 3001
        case .featureProviderCreationFailed: return 3002
        case .imageDecodingFailed: return 4001
        case .imageEncodingFailed: return 4002
        case .invalidImageDimensions: return 4003
        case .missingUnetInputs: return 5001
        case .startingImageProvidedWithoutEncoder: return 5002
        case .startingText2ImgWithoutTextEncoder: return 5003
        case .unsupportedOSVersion: return 5004
        case .errorCreatingPreview: return 5005
        case .safetyCheckFailed: return 6001
        case .safetyCheckerNotAvailable: return 6002
        case .invalidConfiguration: return 7001
        case .invalidSchedulerConfiguration: return 7002
        case .fileReadError: return 8001
        case .invalidFileFormat: return 8002
        }
    }
}

// MARK: - Convenience Methods

extension ImageGeneratorError {
    /// Wraps a throwing closure and converts generic errors to ImageGeneratorError
    public static func wrap<T>(
        _ operation: () throws -> T,
        as errorCase: (Error) -> ImageGeneratorError
    ) rethrows -> T {
        do {
            return try operation()
        } catch let error as ImageGeneratorError {
            throw error
        } catch {
            throw errorCase(error)
        }
    }
}

// MARK: - Legacy Support

/// Legacy error type for backward compatibility
@available(*, deprecated, renamed: "ImageGeneratorError")
public typealias GeneratorError = ImageGeneratorError
