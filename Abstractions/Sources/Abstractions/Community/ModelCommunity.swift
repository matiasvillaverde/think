import Foundation

/// Represents a HuggingFace community that hosts AI models
///
/// Communities are organizations on HuggingFace that specialize in
/// hosting models for specific backends or purposes.
///
/// ## Example Usage
/// ```swift
/// let mlxCommunity = ModelCommunity(
///     id: "mlx-community",
///     displayName: "MLX Community",
///     supportedBackends: [.mlx]
/// )
/// ```
public struct ModelCommunity: Sendable, Codable, Equatable, Hashable {
    /// The community identifier on HuggingFace (e.g., "mlx-community")
    public let id: String

    /// Human-readable display name for the community
    public let displayName: String

    /// The backends that models in this community typically support
    public let supportedBackends: [SendableModel.Backend]

    /// Optional description of the community
    public let description: String?

    /// Initialize a new ModelCommunity
    /// - Parameters:
    ///   - id: Community identifier on HuggingFace
    ///   - displayName: Human-readable name
    ///   - supportedBackends: Backends this community supports
    ///   - description: Optional community description
    public init(
        id: String,
        displayName: String,
        supportedBackends: [SendableModel.Backend],
        description: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.supportedBackends = supportedBackends
        self.description = description
    }
}

// MARK: - Default Communities

extension ModelCommunity {
    /// Default communities for model discovery
    public static let defaultCommunities: [ModelCommunity] = [
        ModelCommunity(
            id: "mlx-community",
            displayName: "MLX Community",
            supportedBackends: [.mlx],
            description: "Community models optimized for Apple Silicon using MLX framework"
        ),
        ModelCommunity(
            id: "coreml-community",
            displayName: "Core ML Community",
            supportedBackends: [.coreml],
            description: "Models optimized for Apple's Core ML framework"
        )
        ,
        ModelCommunity(
            id: "lmstudio-community",
            displayName: "LM Studio Community",
            supportedBackends: [.gguf, .mlx],
            description: "Quantized models in GGUF format for efficient inference"
        ),
        ModelCommunity(
            id: "unsloth",
            displayName: "Unsloth Community",
            supportedBackends: [.gguf],
            description: "Open-source framework for LLM fine-tuning and reinforcement learning."
        )
    ]

    /// Find a community by its identifier
    /// - Parameter id: The community ID to search for
    /// - Returns: The matching community or nil
    public static func find(by id: String) -> ModelCommunity? {
        defaultCommunities.first { $0.id == id }
    }
}
