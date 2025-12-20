import Foundation

/// Represents an AI model with its core identity and requirements.
///
/// `SendableModel` serves as the single source of truth for model identity across the entire codebase.
/// The `id` property is the authoritative identifier that should be used consistently when referencing
/// a model in any context - downloads, storage, database records, etc.
///
/// ## Usage Example
/// ```swift
/// let model = SendableModel(
///     id: UUID(),
///     ramNeeded: 8_000_000_000, // 8GB
///     modelType: .language,
///     backend: .mlx,
///     location: "mlx-community/Llama-3.2-3B-Instruct-4bit"
/// )
/// ```
///
/// ## Important
/// - The `id` must remain constant throughout the model's lifecycle
/// - All model operations (download, storage, lookup) should use this ID
/// - The `location` typically refers to a HuggingFace repository identifier
@DebugDescription
public struct SendableModel: Equatable, Hashable, Sendable {
    /// The unique identifier for this model. This is the single source of truth
    /// for model identity across all modules and operations.
    public let id: UUID

    /// The estimated RAM needed to run this model in bytes
    public let ramNeeded: UInt64

    /// The type of AI model (language, vision, diffusion, etc.)
    public let modelType: ModelType

    /// The backend framework used to run this model
    public let backend: Backend

    /// The model's location identifier, typically a HuggingFace repository ID
    /// (e.g., "mlx-community/Llama-3.2-3B-Instruct-4bit")
    public let location: ModelLocation

    /// Detailed memory requirements (optional for backward compatibility)
    /// 
    /// This property provides comprehensive memory requirement information
    /// including VRAM calculations, quantization details, and overhead.
    /// When nil, use the legacy `ramNeeded` field.
    public let detailedMemoryRequirements: MemoryRequirements?

    /// Model metadata including parameters, architecture, and capabilities
    public let metadata: ModelMetadata?

    /// Model architecture (e.g., llama, mistral, qwen)
    /// This determines the chat template format and other model-specific behaviors
    public let architecture: Architecture

    /// Represents different types of AI models
    public enum ModelType: String, Codable, Equatable, Sendable, Hashable {
        /// Image generation models (e.g., Stable Diffusion)
        case diffusion
        /// Extra-large image generation models
        case diffusionXL = "diffusionXL"
        /// Text generation models (e.g., LLaMA, Mistral)
        case language
        /// Large language models with extended capabilities
        case deepLanguage = "deepLanguage"
        /// Flexible reasoning models (e.g., Qwen3)
        case flexibleThinker = "flexibleThinker"
        /// Vision-language models that can process both text and images
        case visualLanguage = "visualLanguage"
    }

    /// Represents the backend framework for model execution
    public enum Backend: String, Codable, Equatable, Sendable, Hashable, CaseIterable {
        /// MLX framework for Apple Silicon
        case mlx
        /// GGUF format for quantized models
        case gguf
        /// Core ML framework for optimized Apple device inference
        case coreml
        /// Remote API providers (OpenRouter, OpenAI, Anthropic, Google)
        case remote

        /// Backends that run locally and require file storage.
        public static var localCases: [Backend] {
            allCases.filter(\.isLocal)
        }

        /// File patterns to download for each backend
        public var filePatterns: [String] {
            switch self {
            case .coreml:
                return ["*.zip", "*.mlmodel", "*.mlpackage", "*.json", "*.plist"]
            case .gguf:
                return ["*.gguf", "*.json"]
            case .mlx:
                return ["*.safetensors", "*.json", "*.plist"]
            case .remote:
                return [] // No local files needed for remote models
            }
        }

        /// Whether this backend supports ZIP extraction
        public var supportsZipExtraction: Bool {
            switch self {
            case .coreml:
                return true
            case .gguf, .mlx, .remote:
                return false
            }
        }

        /// Directory name for organizing models
        public var directoryName: String {
            self.rawValue
        }

        /// Whether this backend requires downloading model files
        public var requiresDownload: Bool {
            switch self {
            case .mlx, .gguf, .coreml:
                return true
            case .remote:
                return false
            }
        }

        /// Whether this backend runs locally on device
        public var isLocal: Bool {
            switch self {
            case .mlx, .gguf, .coreml:
                return true
            case .remote:
                return false
            }
        }
    }

    public init(
        id: UUID,
        ramNeeded: UInt64,
        modelType: ModelType,
        location: String,
        architecture: Architecture,
        backend: Backend = .mlx,
        detailedMemoryRequirements: MemoryRequirements? = nil,
        metadata: ModelMetadata? = nil
    ) {
        self.id = id
        self.ramNeeded = ramNeeded
        self.modelType = modelType
        self.backend = backend
        self.location = location
        self.architecture = architecture
        self.detailedMemoryRequirements = detailedMemoryRequirements
        self.metadata = metadata
    }

    public var debugDescription: String {
        """
        Model(id: \(id), ramNeeded: \(ramNeeded), modelType: \(modelType), \
        backend: \(backend), architecture: \(architecture), location: \(location))
        """
    }
}
