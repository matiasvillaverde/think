import Foundation
import OSLog
import Observation
import DataAssets

/// Represents a model discovered through HuggingFace community exploration
///
/// This observable class contains all metadata about a model before it's
/// converted to a SendableModel for download. Properties are loaded progressively
/// for optimal performance and user experience.
///
/// ## Progressive Loading Pattern
/// ```swift
/// // Initial creation with basic data
/// let model = DiscoveredModel(
///     id: "mlx-community/Llama-3.2-3B-Instruct-4bit",
///     name: "Llama-3.2-3B-Instruct-4bit",
///     author: "mlx-community",
///     downloads: 15000,
///     likes: 250,
///     tags: ["text-generation", "llama", "conversational"],
///     lastModified: Date(),
///     files: [...],
///     license: "llama3.2",
///     licenseUrl: "https://llama.meta.com/llama3_2/license/"
/// )
///
/// // Later enrichment with detailed data
/// await model.enrich(with: enrichedDetails)
/// ```
@preconcurrency
@MainActor
@Observable
public final class DiscoveredModel: Identifiable, Hashable {
    private let logger = Logger(subsystem: "Abstractions", category: "DiscoveredModel")
    /// The repository ID (e.g., "mlx-community/Llama-3.2-3B")
    public let id: String

    /// The model name (usually the repository name part)
    public let name: String

    /// The author/organization that created the model
    public let author: String

    /// Number of downloads
    public let downloads: Int

    /// Number of likes/stars
    public let likes: Int

    /// Tags associated with the model
    public let tags: [String]

    /// Last modification date
    public let lastModified: Date

    /// Files in the repository (loaded initially)
    public let files: [ModelFile]

    /// The license identifier for this model
    /// 
    /// Examples: "apache-2.0", "mit", "llama3", "gpl-3.0"
    /// 
    /// This value is extracted from the HuggingFace API's `cardData.license` field.
    /// Models without license information will have `nil`.
    public let license: String?

    /// URL to the full license text
    ///
    /// This URL is automatically mapped from common license identifiers
    /// to their official documentation pages. For example:
    /// - "apache-2.0" → "https://www.apache.org/licenses/LICENSE-2.0"
    /// - "mit" → "https://opensource.org/licenses/MIT"
    /// - "llama3" → "https://llama.meta.com/llama3/license/"
    ///
    /// Unknown or proprietary licenses will have `nil` even if a license identifier exists.
    public let licenseUrl: String?

    /// Optional model-specific metadata
    public let metadata: [String: String]

    // MARK: - Progressive Properties (Loaded Later)

    /// The model card (README) content
    /// Loaded progressively for performance
    public var modelCard: String?

    /// Detected backend support based on file analysis
    /// Updated after enrichment
    public var detectedBackends: [SendableModel.Backend] = []

    /// Image URLs extracted from model card or original model
    ///
    /// Populated progressively to avoid performance impact on list views.
    /// Contains absolute URLs to relevant images (architecture diagrams,
    /// sample outputs) with badges and logos filtered out.
    ///
    /// For converted models, may contain images from the original model
    /// if the converted model's card lacks visual content.
    public var imageUrls: [String] = []

    /// Comprehensive card data metadata from HuggingFace API
    ///
    /// Contains all structured metadata available from the model's cardData,
    /// including technical details, licensing, relationships, and visual content.
    /// Used for enhanced image extraction and model understanding.
    public var cardData: ModelCardData?

    /// Initialize a new DiscoveredModel with basic data
    /// Progressive properties (modelCard, imageUrls, cardData, detectedBackends) 
    /// are initialized to nil/empty and populated later via enrichment
    public init(
        id: String,
        name: String,
        author: String,
        downloads: Int,
        likes: Int,
        tags: [String],
        lastModified: Date,
        files: [ModelFile] = [],
        license: String? = nil,
        licenseUrl: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.author = author
        self.downloads = downloads
        self.likes = likes
        self.tags = tags
        self.lastModified = lastModified
        self.files = files
        self.license = license
        self.licenseUrl = licenseUrl
        self.metadata = metadata

        // Progressive properties start as nil/empty
        self.modelCard = nil
        self.detectedBackends = []
        self.imageUrls = []
        self.cardData = nil
    }

    /// Enrich the model with detailed data loaded asynchronously
    /// This method updates the progressive properties in-place, 
    /// triggering UI updates through SwiftUI's observation system
    public func enrich(with details: EnrichedModelDetails) {
        logger.info("Enriching model '\(self.name)' (id: \(self.id))")
        logger.info("ModelCard: \(details.modelCard.map { "\($0.prefix(50))..." } ?? "nil")")
        logger.info("ImageUrls: \(details.imageUrls.count) images")
        logger.info("CardData: \(details.cardData != nil ? "present" : "nil")")
        logger.info("Backends: \(details.detectedBackends.map(\.rawValue))")

        self.modelCard = details.modelCard
        self.cardData = details.cardData
        self.imageUrls = details.imageUrls
        if !details.detectedBackends.isEmpty {
            self.detectedBackends = details.detectedBackends
        }

        logger.info("Model enrichment complete for '\(self.name)'")
    }
}

// MARK: - Computed Properties

extension DiscoveredModel {
    /// Total size of all model files
    public var totalSize: Int64 {
        files.compactMap(\.size).reduce(0, +)
    }

    /// Infers the model architecture from the model ID and tags
    /// Uses Architecture.detect to determine the architecture type
    public var inferredArchitecture: Architecture {
        let architecture = Architecture.detect(from: id, tags: tags)
        logger.info("\(self.name) architecture: \(architecture.rawValue)")
        return architecture
    }

    /// Formatted total size string
    public var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    /// Check if this model is the recommended model for any memory tier
    public var isRecommendedForTier: Bool {
        RecommendedModels.isRecommendedForTier(id)
    }

    /// Get the recommendation type for this model
    public var recommendationType: RecommendedModels.RecommendationType? {
        RecommendedModels.getRecommendationType(for: id)
    }

    /// Check if this model is recommended for fast tasks
    public var isRecommendedForFastTasks: Bool {
        RecommendedModels.isRecommendedForFastTasks(id)
    }

    /// Check if this model is recommended for complex tasks
    public var isRecommendedForComplexTasks: Bool {
        RecommendedModels.isRecommendedForComplexTasks(id)
    }

    /// Whether this model has any detected backends
    public var hasDetectedBackends: Bool {
        !detectedBackends.isEmpty
    }

    /// Primary detected backend (first in the list)
    public var primaryBackend: SendableModel.Backend? {
        guard !detectedBackends.isEmpty else {
            return nil
        }

        if let localBackend = detectedBackends.first(where: \.isLocal) {
            return localBackend
        }

        return detectedBackends.first
    }

    /// Inferred model type from tags
    public var inferredModelType: SendableModel.ModelType? {
        // Check tags for model type hints
        if tags.contains(where: { $0.lowercased().contains("diffusion") }) {
            // Check for XL variant
            let hasXL = tags.contains(where: { tag in
                let lower = tag.lowercased()
                return lower.contains("xl") || lower.contains("sdxl")
            })
            return hasXL ? .diffusionXL : .diffusion
        }

        if tags.contains(where: { $0.lowercased().contains("vision") }) ||
           tags.contains(where: { $0.lowercased().contains("multimodal") }) {
            return .visualLanguage
        }

        // Check for Qwen models (flexible thinker) before general language models
        if tags.contains(where: { $0.lowercased().contains("qwen") }) ||
           name.lowercased().contains("qwen") {
            return .flexibleThinker
        }

        if tags.contains(where: { $0.lowercased().contains("text-generation") }) ||
           tags.contains(where: { $0.lowercased().contains("language-model") }) {
            // Check model size for deep vs regular
            if name.lowercased().contains("70b") ||
               name.lowercased().contains("65b") ||
               name.lowercased().contains("40b") {
                return .deepLanguage
            }
            return .language
        }

        // Default to language model
        return .language
    }

    /// Whether this appears to be a valid AI model
    public var isValidModel: Bool {
        // Must have files and at least one detected backend
        !files.isEmpty && !detectedBackends.isEmpty
    }

    /// Whether this model has image URLs populated
    public var hasImages: Bool {
        !imageUrls.isEmpty
    }

    /// Number of available images
    public var imageCount: Int {
        imageUrls.count
    }

    // MARK: - Hashable

    /// Hashes the essential components of this value by feeding them into the given hasher
    /// - Parameter hasher: The hasher to use when combining the components
    nonisolated public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// Compares two DiscoveredModel instances for equality
    /// - Parameters:
    ///   - lhs: The left-hand side model
    ///   - rhs: The right-hand side model
    /// - Returns: True if the models have the same ID
    nonisolated public static func == (lhs: DiscoveredModel, rhs: DiscoveredModel) -> Bool {
        lhs.id == rhs.id
    }
}
