import Abstractions
import CryptoKit
import Foundation

/// Service for converting discovered models to SendableModel format
///
/// Handles RAM estimation, model type detection, and backend selection.
internal actor ModelConverter {
    private let logger: ModelDownloaderLogger

    internal init() {
        self.logger = ModelDownloaderLogger(
            subsystem: "com.think.modeldownloader",
            category: "ModelConverter"
        )
    }

    /// Generate a deterministic UUID based on a string
    /// This ensures the same model location always produces the same UUID
    nonisolated private func generateDeterministicUUID(from string: String) -> UUID {
        // Use SHA256 to generate a consistent hash from the string
        let hash: SHA256Digest = SHA256.hash(data: Data(string.utf8))

        // Take the first 16 bytes of the hash for the UUID
        let hashBytes: [UInt8] = Array(hash)

        // Convert to UUID format (8-4-4-4-12 hex characters)
        return UUID(uuid: (
            hashBytes[0], hashBytes[1], hashBytes[2], hashBytes[3],
            hashBytes[4], hashBytes[5], hashBytes[6], hashBytes[7],
            hashBytes[8], hashBytes[9], hashBytes[10], hashBytes[11],
            hashBytes[12], hashBytes[13], hashBytes[14], hashBytes[15]
        ))
    }

    /// Convert a DiscoveredModel to SendableModel
    /// - Parameters:
    ///   - discovered: The discovered model to convert
    ///   - preferredBackend: Optional preferred backend (uses primary detected if nil)
    /// - Returns: A SendableModel ready for download
    /// - Throws: HuggingFaceError if conversion fails
    @MainActor
    internal func toSendableModel(
        _ discovered: DiscoveredModel,
        preferredBackend: SendableModel.Backend? = nil
    ) async throws -> SendableModel {
        await logger.info("Converting discovered model", metadata: [
            "id": discovered.id,
            "backends": discovered.detectedBackends.map(\.rawValue)
        ])

        // Validate model has detected backends
        guard !discovered.detectedBackends.isEmpty else {
            await logger.error("No backends detected for model", metadata: ["id": discovered.id])
            throw HuggingFaceError.unsupportedFormat
        }

        // Select backend
        let backend: SendableModel.Backend
        if let preferred = preferredBackend,
           discovered.detectedBackends.contains(preferred) {
            backend = preferred
            await logger.debug("Using preferred backend", metadata: ["backend": backend.rawValue])
        } else {
            backend = discovered.primaryBackend ?? discovered.detectedBackends[0]
            await logger.debug("Using primary backend", metadata: ["backend": backend.rawValue])
        }

        // Extract or estimate RAM requirements
        let ramNeeded: UInt64 = await extractRAMRequirements(from: discovered)

        // Determine model type
        let modelType: SendableModel.ModelType = discovered.inferredModelType ?? .language

        // Generate deterministic ID based on model location
        // This ensures the same DiscoveredModel always gets the same UUID
        let modelId: UUID = generateDeterministicUUID(from: discovered.id)

        // Detect architecture from the discovered model
        let architecture: Architecture = discovered.inferredArchitecture

        // Create minimal metadata with architecture
        let metadata: Abstractions.ModelMetadata = Abstractions.ModelMetadata(
            parameters: ModelParameters(count: 0, formatted: "Unknown"),
            architecture: architecture,
            capabilities: [], // Empty capabilities for now
            quantizations: [],
            version: nil
        )

        await logger.info("Created SendableModel", metadata: [
            "id": modelId.uuidString,
            "backend": backend.rawValue,
            "modelType": modelType.rawValue,
            "ramNeeded": ramNeeded,
            "location": discovered.id,
            "architecture": architecture.rawValue
        ])

        return SendableModel(
            id: modelId,
            ramNeeded: ramNeeded,
            modelType: modelType,
            location: discovered.id,
            architecture: architecture,
            backend: backend,
            locationKind: .huggingFace,
            detailedMemoryRequirements: nil,
            metadata: metadata
        )
    }

    /// Convert to ModelInfo for preview (without downloading)
    /// - Parameter discovered: The discovered model
    /// - Returns: A ModelInfo preview
    @MainActor
    internal func toModelInfo(_ discovered: DiscoveredModel) -> ModelInfo {
        ModelInfo(
            id: UUID(),
            name: discovered.name,
            backend: discovered.primaryBackend ?? .mlx,
            location: URL(fileURLWithPath: "/tmp/preview/\(discovered.id)"),
            totalSize: discovered.totalSize,
            downloadDate: Date(),
            metadata: [
                "author": discovered.author,
                "downloads": String(discovered.downloads),
                "likes": String(discovered.likes),
                "lastModified": ISO8601DateFormatter().string(from: discovered.lastModified),
                "tags": discovered.tags.joined(separator: ",")
            ]
        )
    }

    /// Extract RAM requirements from model
    @MainActor
    private func extractRAMRequirements(from model: DiscoveredModel) async -> UInt64 {
        // First, try to extract from model card
        if let ramFromCard = await extractRAMFromModelCard(model.modelCard) {
            await logger.debug("Extracted RAM from model card", metadata: [
                "ram": ramFromCard,
                "model": model.id
            ])
            return ramFromCard
        }

        // Otherwise, estimate from file sizes
        let estimated: UInt64 = estimateRAM(from: model)
        await logger.debug("Estimated RAM from file sizes", metadata: [
            "ram": estimated,
            "model": model.id
        ])
        return estimated
    }

    /// Extract RAM requirements from model card text
    private func extractRAMFromModelCard(_ modelCard: String?) -> UInt64? {
        guard let card = modelCard else { return nil }

        // Look for common RAM requirement patterns
        let patterns: [String] = [
            // "requires 8GB RAM", "needs 16GB memory"
            "(?:requires?|needs?)\\s+(\\d+)\\s*GB\\s*(?:of\\s+)?(?:RAM|memory)",
            // "RAM: 8GB", "Memory: 16GB"
            "(?:RAM|Memory):\\s*(\\d+)\\s*GB",
            // "8GB RAM required"
            "(\\d+)\\s*GB\\s*(?:RAM|memory)\\s*required",
            // In tables: "| RAM | 8GB |"
            "\\|\\s*(?:RAM|Memory)\\s*\\|\\s*(\\d+)\\s*GB\\s*\\|"
        ]

        for pattern in patterns {
            if let regex: NSRegularExpression = try? NSRegularExpression(
                pattern: pattern,
                options: .caseInsensitive
            ) {
                let range: NSRange = NSRange(location: 0, length: card.utf16.count)
                if let match = regex.firstMatch(in: card, options: [], range: range) {
                    // Extract the capture group (index 1)
                    if match.numberOfRanges > 1 {
                        let gbRange: NSRange = match.range(at: 1)
                        if let swiftRange = Range(gbRange, in: card),
                           let gbValue: Int = Int(card[swiftRange]) {
                            return UInt64(gbValue) * 1_024 * 1_024 * 1_024 // Convert GB to bytes
                        }
                    }
                }
            }
        }

        return nil
    }

    /// Estimate RAM based on model characteristics
    @MainActor
    private func estimateRAM(from model: DiscoveredModel) -> UInt64 {
        let totalSize: UInt64 = UInt64(max(0, model.totalSize))

        // Base multiplier depends on model type
        var multiplier: Double = 1.2 // Default conservative estimate

        // Adjust multiplier based on model type
        switch model.inferredModelType {
        case .diffusion, .diffusionXL:
            multiplier = 1.5 // Image generation needs more overhead

        case .visualLanguage:
            multiplier = 1.4 // Vision models need extra buffers

        case .deepLanguage, .flexibleThinker:
            multiplier = 1.3 // Large language models

        case .language:
            multiplier = 1.2 // Standard language models

        case .none:
            multiplier = 1.2
        }

        // Check for quantization hints in filename
        let hasQuantization: Bool = model.files.contains { file in
            let name: String = file.filename.lowercased()
            return name.contains("q4") || name.contains("q5") ||
                   name.contains("q8") || name.contains("4bit") ||
                   name.contains("8bit")
        }

        if hasQuantization {
            multiplier *= 0.8 // Quantized models use less RAM
        }

        // Calculate estimated RAM
        let estimatedRAM: UInt64 = UInt64(Double(totalSize) * multiplier)

        // Round up to nearest GB for cleaner estimates
        let bytesPerGB: UInt64 = 1_024 * 1_024 * 1_024
        let gbSize: UInt64 = (estimatedRAM + (bytesPerGB - 1)) / bytesPerGB
        return gbSize * bytesPerGB
    }
}
