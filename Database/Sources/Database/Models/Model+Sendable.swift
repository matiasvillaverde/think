import Foundation
import Abstractions

// MARK: - Sendable Conversion
extension Model {
    public func toSendable() -> SendableModel {
        // Create metadata from model properties
        let metadata = ModelMetadata(
            parameters: ModelParameters(count: parameters, formatted: formatParameterCount(parameters)),
            architecture: architecture ?? .unknown,
            capabilities: Set(), // No longer using capabilities
            quantizations: [], // Quantization info not stored in Model
            version: nil // Version not stored in Model
        )

        let locationValue: String
        switch locationKind {
        case .localFile:
            locationValue = locationLocal ?? ""
        case .huggingFace, .remote:
            locationValue = locationHuggingface ?? ""
        }

        return SendableModel(
            id: id,
            ramNeeded: ramNeeded,
            modelType: type,
            location: locationValue,
            architecture: architecture ?? .unknown,
            backend: backend,
            locationKind: locationKind,
            locationLocal: locationLocal,
            locationBookmark: locationBookmark,
            detailedMemoryRequirements: nil,
            metadata: metadata
        )
    }

    private func formatParameterCount(_ count: UInt64) -> String {
        if count >= 1_000_000_000 {
            return String(format: "%.1fB", Double(count) / 1_000_000_000.0)
        } else if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000.0)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000.0)
        } else {
            return "\(count)"
        }
    }
}
