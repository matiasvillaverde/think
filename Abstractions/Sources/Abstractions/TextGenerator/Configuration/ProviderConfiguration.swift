import Foundation

/// Configuration options for creating provider instances.
///
/// This structure contains the common configuration needed by most providers.
/// Specific providers may extend this with their own configuration types.
public struct ProviderConfiguration: Sendable {
    /// The API endpoint URL.
    ///
    /// For remote providers, this is the base URL of the API.
    /// For local providers, this might be a model file path.
    public let location: URL

    /// Authentication credentials.
    public let authentication: Authentication

    /// The name or identifier of the model to use.
    ///
    /// This identifies which specific model the provider should load.
    /// The format depends on the provider:
    /// - For API providers: Often a model ID like "gpt-4", "claude-3", etc.
    /// - For local providers: May be a model file name or path component
    /// - For Hugging Face: Repository ID like "meta-llama/Llama-2-7b"
    ///
    /// - Note: This field alone uniquely identifies a model within a provider's
    ///   context. Combined with the provider type and location, it forms a
    ///   complete model reference.
    public let modelName: String

    /// Configuration for compute resources used during inference.
    ///
    /// This defines the computational parameters like context size, batch size,
    /// and thread count that control how the model processes requests.
    public let compute: ComputeConfiguration

    /// Creates a provider configuration with required connection details.
    ///
    /// - Parameters:
    ///   - location: The API endpoint URL or model file path
    ///   - authentication: Authentication credentials for the provider
    ///   - modelName: The name or identifier of the model to use
    ///   - compute: Configuration for compute resources
    public init(
        location: URL,
        authentication: Authentication,
        modelName: String,
        compute: ComputeConfiguration
    ) {
        self.location = location
        self.authentication = authentication
        self.modelName = modelName
        self.compute = compute
    }
}
