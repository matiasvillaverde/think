import Foundation

/// Represents a model available from a remote provider.
public struct RemoteModel: Identifiable, Hashable, Sendable {
    /// The provider offering the model.
    public let provider: RemoteProviderType
    /// Provider-specific model identifier.
    public let modelId: String
    /// Display name for UI.
    public let displayName: String
    /// Optional description text.
    public let description: String?
    /// Optional context length (tokens).
    public let contextLength: Int?
    /// Model type (language/vision/etc.).
    public let type: SendableModel.ModelType
    /// Pricing availability for the model.
    public let pricing: RemoteModelPricing
    /// Full model location used by remote sessions.
    public let location: String

    public var id: String { location }

    public init(
        provider: RemoteProviderType,
        modelId: String,
        displayName: String,
        description: String? = nil,
        contextLength: Int? = nil,
        type: SendableModel.ModelType = .language,
        pricing: RemoteModelPricing = .unknown
    ) {
        self.provider = provider
        self.modelId = modelId
        self.displayName = displayName
        self.description = description
        self.contextLength = contextLength
        self.type = type
        self.pricing = pricing
        self.location = "\(provider.rawValue.lowercased()):\(modelId)"
    }
}

/// Pricing category for remote models.
public enum RemoteModelPricing: String, Sendable {
    case free
    case paid
    case unknown
}
