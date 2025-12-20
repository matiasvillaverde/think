import Foundation

/// Information about a specific quantization variant of a model
///
/// This structure represents an individual quantization option available
/// for a model, including its level, file information, and memory requirements.
///
/// ## Example
/// ```swift
/// let quantization = QuantizationInfo(
///     level: .q4_k_m,
///     fileSize: 2_979_069_952, // ~2.79 GB
///     fileName: "gemma-3n-E2B-it-Q4_K_M.gguf",
///     sha: "abc123...",
///     memoryRequirements: MemoryRequirements(...)
/// )
/// ```
public struct QuantizationInfo: Sendable, Codable, Equatable, Hashable {
    /// Quantization level
    public let level: QuantizationLevel

    /// Size of the quantized model file in bytes
    public let fileSize: UInt64

    /// Optional filename for this quantization
    public let fileName: String?

    /// SHA hash of the file (if available)
    public let sha: String?

    /// Calculated memory requirements for this quantization
    public let memoryRequirements: MemoryRequirements?

    /// Whether this quantization is recommended for most users
    public let isRecommended: Bool

    /// Quality score (0.0 - 1.0) for this quantization
    public var qualityScore: Double {
        level.qualityLevel
    }

    public init(
        level: QuantizationLevel,
        fileSize: UInt64,
        fileName: String? = nil,
        sha: String? = nil,
        memoryRequirements: MemoryRequirements? = nil,
        isRecommended: Bool = false
    ) {
        self.level = level
        self.fileSize = fileSize
        self.fileName = fileName
        self.sha = sha
        self.memoryRequirements = memoryRequirements
        self.isRecommended = isRecommended
    }
}

// MARK: - Formatted Properties

public extension QuantizationInfo {
    /// Formatted file size
    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }

    /// Formatted memory requirement
    var formattedMemoryRequired: String {
        guard let memReq = memoryRequirements else {
            return "Unknown"
        }
        return memReq.formattedTotalMemory
    }

    /// Display name combining quantization level and size
    var displayName: String {
        "\(level.displayName) (\(formattedFileSize))"
    }

    /// Detailed description including quality and memory info
    var detailedDescription: String {
        var parts = [String]()

        parts.append("\(level.displayName)")
        parts.append("Size: \(formattedFileSize)")

        if let memReq = memoryRequirements {
            parts.append("Memory: \(memReq.formattedTotalMemory)")
        }

        parts.append("Quality: \(Int(qualityScore * 100))%")

        if isRecommended {
            parts.append("✓ Recommended")
        }

        return parts.joined(separator: " • ")
    }
}

// MARK: - Comparison and Sorting

public extension QuantizationInfo {
    /// Compare quantizations by quality (higher quality first)
    static func byQuality(_ lhs: QuantizationInfo, _ rhs: QuantizationInfo) -> Bool {
        lhs.qualityScore > rhs.qualityScore
    }

    /// Compare quantizations by size (smaller first)
    static func bySize(_ lhs: QuantizationInfo, _ rhs: QuantizationInfo) -> Bool {
        lhs.fileSize < rhs.fileSize
    }

    /// Compare quantizations by memory requirements (less memory first)
    static func byMemoryRequirement(_ lhs: QuantizationInfo, _ rhs: QuantizationInfo) -> Bool {
        guard let lhsMem = lhs.memoryRequirements?.totalMemory,
              let rhsMem = rhs.memoryRequirements?.totalMemory else {
            return lhs.fileSize < rhs.fileSize // Fallback to file size
        }
        return lhsMem < rhsMem
    }
}

// MARK: - Quantization Detection

public extension QuantizationInfo {
    /// Create QuantizationInfo from a ModelFile
    /// - Parameters:
    ///   - file: The model file
    ///   - calculator: Optional VRAM calculator for memory requirements
    ///   - parameters: Optional parameter count for accurate calculation
    /// - Returns: QuantizationInfo if quantization can be detected
    static func from(
        file: ModelFile,
        calculator: VRAMCalculatorProtocol? = nil,
        parameters: UInt64? = nil
    ) -> QuantizationInfo? {
        guard let level = QuantizationLevel.detectFromFilename(file.filename),
              let size = file.size else {
            return nil
        }

        // Calculate memory requirements if we have the necessary info
        let memoryRequirements: MemoryRequirements? = {
            guard let calc = calculator else {
                return nil
            }

            if let params = parameters {
                // Accurate calculation with known parameters
                return try? calc.calculateMemoryRequirements(
                    parameters: params,
                    quantization: level,
                    overheadPercentage: 0.25
                )
            }
            // Estimate from file size
            return calc.estimateFromFileSize(
                fileSize: UInt64(size),
                quantization: level,
                overheadPercentage: 0.25
            )
        }()

        // Determine if this is a recommended quantization
        let isRecommended = isRecommendedQuantization(level)

        return QuantizationInfo(
            level: level,
            fileSize: UInt64(size),
            fileName: file.filename,
            sha: file.sha,
            memoryRequirements: memoryRequirements,
            isRecommended: isRecommended
        )
    }

    /// Determine if a quantization level is generally recommended
    private static func isRecommendedQuantization(_ level: QuantizationLevel) -> Bool {
        switch level {
        case .q4_k_m, .q5_k_m, .int4, .fp16:
            return true // Good balance of quality and size
        default:
            return false
        }
    }
}
