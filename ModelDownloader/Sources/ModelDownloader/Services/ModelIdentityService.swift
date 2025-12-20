import Abstractions
import CryptoKit
import Foundation

/// Service responsible for model identity resolution and UUID generation
///
/// This service consolidates all model identity logic:
/// - Deterministic UUID generation from model location
/// - Location normalization and validation
/// - Component extraction (author/name)
/// - Identity resolution from various model representations
public actor ModelIdentityService {
    /// Cache for generated UUIDs to improve performance
    private var uuidCache: [String: UUID] = [:]

    /// Namespace for UUID generation
    private let namespace: UUID = UUID(uuidString: "6ba7b810-9dad-11d1-80b4-00c04fd430c8")!

    /// Creates a new model identity service
    public init() {}

    /// Generate a deterministic UUID for a model location
    /// - Parameter location: The model location (e.g., "mlx-community/Llama-3.2-3B")
    /// - Returns: A deterministic UUID based on the normalized location
    public func generateModelId(for location: String) -> UUID {
        let normalized: String = normalizeLocation(location)

        // Check cache first
        if let cached: UUID = uuidCache[normalized] {
            return cached
        }

        // Generate deterministic UUID
        let data: Data = Data(normalized.utf8)
        let hash: SHA256.Digest = SHA256.hash(data: namespace.uuidString.data(using: .utf8)! + data)

        // Convert first 16 bytes of hash to UUID
        let hashBytes: [UInt8] = Array(hash)
        let uuidBytes: [UInt8] = Array(hashBytes[0..<16])

        // Set version (5) and variant bits according to UUID v5 spec
        var bytes: [UInt8] = uuidBytes
        bytes[6] = (bytes[6] & 0x0F) | 0x50  // Version 5
        bytes[8] = (bytes[8] & 0x3F) | 0x80  // Variant bits

        let uuid: UUID = UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))

        // Cache the result
        uuidCache[normalized] = uuid

        return uuid
    }

    /// Normalize a model location for consistent comparison
    /// - Parameter location: The raw location string
    /// - Returns: Normalized location in lowercase, trimmed, without URL prefix
    public func normalizeLocation(_ location: String) -> String {
         var normalized: String = location.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove common URL prefixes
        let prefixes: [String] = [
            "https://huggingface.co/",
            "http://huggingface.co/",
            "huggingface.co/"
        ]

        for prefix: String in prefixes where normalized.lowercased().hasPrefix(prefix) {
            normalized = String(normalized.dropFirst(prefix.count))
            break
        }

        // Convert to lowercase for consistent comparison
        return normalized.lowercased()
    }

    /// Extract author and model name components from a location
    /// - Parameter location: The model location
    /// - Returns: Tuple of (author, name) or (nil, nil) if invalid format
    public func extractComponents(from location: String) -> (author: String?, name: String?) {
        let normalized: String = normalizeLocation(location)

        // Return nil for empty normalized location
        guard !normalized.isEmpty else {
            return (nil, nil)
        }

        let components: [Substring] = normalized.split(separator: "/", maxSplits: 1)

        guard components.count == 2,
              !components[0].isEmpty,
              !components[1].isEmpty,
              !String(components[1]).contains("/") else {  // Reject double slashes
            return (nil, nil)
        }

        // Return original case components from the input
        let originalComponents: [Substring] = location
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "https://huggingface.co/", with: "")
            .replacingOccurrences(of: "http://huggingface.co/", with: "")
            .replacingOccurrences(of: "huggingface.co/", with: "")
            .split(separator: "/", maxSplits: 1)

        if originalComponents.count == 2 {
            return (String(originalComponents[0]), String(originalComponents[1]))
        }

        return (String(components[0]), String(components[1]))
    }

    /// Validate if a location string is in the correct format
    /// - Parameter location: The location to validate
    /// - Returns: true if valid format (author/model), false otherwise
    public func isValidLocation(_ location: String) -> Bool {
        let (author, name): (String?, String?) = extractComponents(from: location)
        return author != nil && name != nil
    }

    /// Create a SendableModel with proper identity
    /// - Parameters:
    ///   - location: Model location
    ///   - backend: Model backend
    ///   - modelType: Type of model
    ///   - ramNeeded: RAM requirements
    /// - Returns: SendableModel with deterministic ID
    public func createSendableModel(
        location: String,
        backend: SendableModel.Backend,
        modelType: SendableModel.ModelType,
        ramNeeded: UInt64
    ) -> SendableModel {
        let id: UUID = generateModelId(for: location)

        return SendableModel(
            id: id,
            ramNeeded: ramNeeded,
            modelType: modelType,
            location: location,
            architecture: .unknown,
            backend: backend
        )
    }

    /// Resolve model identity from a DiscoveredModel
    /// - Parameter discovered: The discovered model
    /// - Returns: Model identity information
    @preconcurrency
    @MainActor
    public func resolveIdentity(from discovered: DiscoveredModel) async -> ModelIdentity {
        let location: String = discovered.id
        let id: UUID = await generateModelId(for: location)
        let (author, name): (String?, String?) = await extractComponents(from: location)

        return ModelIdentity(
            id: id,
            location: location,
            author: author ?? discovered.author,
            name: name ?? discovered.name
        )
    }
}

/// Model identity information
public struct ModelIdentity: Sendable {
    public let id: UUID
    public let location: String
    public let author: String
    public let name: String
}
