import Foundation

/// Comprehensive model card data structure
///
/// Contains all structured metadata available from HuggingFace cardData,
/// providing rich information about models beyond basic properties.
/// This data is typically loaded from the `cardData` field of HuggingFace API responses.
///
/// ## HuggingFace Integration
/// ```swift
/// // Parsed from HuggingFace API response
/// let cardData = ModelCardData(
///     license: "llama3.2",
///     licenseName: "Llama 3.2 Community License",
///     baseModel: ["meta-llama/Llama-3.2-7B"],
///     pipelineTag: "text-generation",
///     libraryName: "transformers",
///     language: ["en"],
///     datasets: ["training-dataset-v1"]
/// )
/// ```
public struct ModelCardData: Sendable, Codable, Equatable, Hashable {
    // MARK: - License Information

    /// License identifier (e.g., "apache-2.0", "mit", "llama3.2")
    public let license: String?

    /// Human-readable license name
    public let licenseName: String?

    /// URL to full license text
    public let licenseLink: String?

    // MARK: - Model Relationships

    /// Base models this model is derived from
    public let baseModel: [String]

    /// Relationship type to base model (e.g., "fine-tune", "merge")
    public let baseModelRelation: String?

    // MARK: - Visual Content

    /// Thumbnail image URL for model card
    public let thumbnail: String?

    // MARK: - Technical Metadata

    /// Pipeline tag (e.g., "text-generation", "image-classification")
    public let pipelineTag: String?

    /// ML library name (e.g., "transformers", "diffusers")
    public let libraryName: String?

    /// Supported languages
    public let language: [String]

    /// Training datasets used
    public let datasets: [String]

    /// Model tags for categorization
    public let tags: [String]

    // MARK: - Gating Information

    /// Additional prompt for gated model access
    public let extraGatedPrompt: String?

    /// Widget examples for model demonstration
    public let widget: [WidgetExample]

    /// Initialize model card data
    /// - Parameters:
    ///   - license: License identifier
    ///   - licenseName: Human-readable license name
    ///   - licenseLink: URL to license text
    ///   - baseModel: Array of base model identifiers
    ///   - baseModelRelation: Relationship to base models
    ///   - thumbnail: Thumbnail image URL
    ///   - pipelineTag: ML pipeline type
    ///   - libraryName: ML library name
    ///   - language: Supported languages
    ///   - datasets: Training datasets
    ///   - tags: Model tags
    ///   - extraGatedPrompt: Gating access prompt
    ///   - widget: Widget examples
    public init(
        license: String? = nil,
        licenseName: String? = nil,
        licenseLink: String? = nil,
        baseModel: [String] = [],
        baseModelRelation: String? = nil,
        thumbnail: String? = nil,
        pipelineTag: String? = nil,
        libraryName: String? = nil,
        language: [String] = [],
        datasets: [String] = [],
        tags: [String] = [],
        extraGatedPrompt: String? = nil,
        widget: [WidgetExample] = []
    ) {
        self.license = license
        self.licenseName = licenseName
        self.licenseLink = licenseLink
        self.baseModel = baseModel
        self.baseModelRelation = baseModelRelation
        self.thumbnail = thumbnail
        self.pipelineTag = pipelineTag
        self.libraryName = libraryName
        self.language = language
        self.datasets = datasets
        self.tags = tags
        self.extraGatedPrompt = extraGatedPrompt
        self.widget = widget
    }

    private enum CodingKeys: String, CodingKey {
        case license
        case licenseName = "license_name"
        case licenseLink = "license_link"
        case baseModel = "base_model"
        case baseModelRelation = "base_model_relation"
        case thumbnail
        case pipelineTag = "pipeline_tag"
        case libraryName = "library_name"
        case language
        case datasets
        case tags
        case extraGatedPrompt = "extra_gated_prompt"
        case widget
    }
}
