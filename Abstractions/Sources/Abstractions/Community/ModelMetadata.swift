import Foundation

/// Extended metadata for AI models
///
/// This structure contains comprehensive information about a model's
/// architecture, capabilities, and available quantizations.
///
/// ## Example
/// ```swift
/// let metadata = ModelMetadata(
///     parameters: ModelParameters(count: 7_000_000_000, formatted: "7B"),
///     architecture: .llama,
///     capabilities: [.textGeneration, .instructFollowing, .reasoning],
///     quantizations: [
///         QuantizationInfo(level: .fp16, fileSize: 14_000_000_000),
///         QuantizationInfo(level: .int4, fileSize: 3_500_000_000)
///     ],
///     contextLength: 4096,
///     license: "llama3.2",
///     baseModel: "Meta-Llama-3.2-7B"
/// )
/// ```
public struct ModelMetadata: Sendable, Codable, Equatable, Hashable {
    /// Model parameter information
    public let parameters: ModelParameters

    /// Model architecture type
    public let architecture: Architecture

    /// Architecture version (e.g., "2", "3.2", "v2")
    public let version: String?

    /// Model capabilities
    public let capabilities: Set<Capability> // TODO: Remove

    /// Available quantization options
    public let quantizations: [QuantizationInfo]

    /// Maximum context length (tokens)
    public let contextLength: Int?

    /// License identifier
    public let license: String?

    /// Base model name (if this is a fine-tune)
    public let baseModel: String?

    /// Additional metadata
    public let additionalInfo: [String: String]

    public init(
        parameters: ModelParameters,
        architecture: Architecture,
        capabilities: Set<Capability>,
        quantizations: [QuantizationInfo],
        version: String? = nil,
        contextLength: Int? = nil,
        license: String? = nil,
        baseModel: String? = nil,
        additionalInfo: [String: String] = [:]
    ) {
        self.parameters = parameters
        self.architecture = architecture
        self.version = version
        self.capabilities = capabilities
        self.quantizations = quantizations
        self.contextLength = contextLength
        self.license = license
        self.baseModel = baseModel
        self.additionalInfo = additionalInfo
    }
}

extension ModelMetadata {
    /// Get the best quantization for given memory constraints
    /// - Parameter availableMemory: Available memory in bytes
    /// - Returns: Best quantization that fits, or nil if none fit
    func bestQuantization(for availableMemory: UInt64) -> QuantizationInfo? {
        // Sort by quality (highest first) and filter by what fits
        let suitable = quantizations
            .filter { quant in
                guard let memReq = quant.memoryRequirements else {
                    return false
                }
                return memReq.totalMemory <= availableMemory
            }
            .sorted { $0.level.qualityLevel > $1.level.qualityLevel }

        return suitable.first
    }

    /// Check if model supports a specific capability
    func supports(_ capability: Capability) -> Bool {
        capabilities.contains(capability)
    }

    /// Get architecture display name with version
    var architectureDisplayName: String {
        architecture.displayName(version: version)
    }
}
