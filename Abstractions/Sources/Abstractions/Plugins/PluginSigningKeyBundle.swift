import Foundation

/// Bundle of signing keys used for plugin signature verification.
public struct PluginSigningKeyBundle: Sendable, Codable, Equatable {
    public let issuedAt: Date
    public let keys: [PluginSigningKey]
    public let signature: String?
    public let signatureKeyId: String?
    public let signatureAlgorithm: PluginSignatureAlgorithm?

    public init(
        issuedAt: Date,
        keys: [PluginSigningKey],
        signature: String? = nil,
        signatureKeyId: String? = nil,
        signatureAlgorithm: PluginSignatureAlgorithm? = nil
    ) {
        self.issuedAt = issuedAt
        self.keys = keys
        self.signature = signature
        self.signatureKeyId = signatureKeyId
        self.signatureAlgorithm = signatureAlgorithm
    }

    /// Canonical payload used for signature verification.
    public var signaturePayload: String? {
        let orderedKeys: [PluginSigningKey] = keys.sorted { lhs, rhs in
            if lhs.id == rhs.id {
                return lhs.algorithm.rawValue < rhs.algorithm.rawValue
            }
            return lhs.id < rhs.id
        }
        let payload: Payload = Payload(issuedAt: issuedAt, keys: orderedKeys)
        let encoder: JSONEncoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(payload) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private struct Payload: Codable {
        let issuedAt: Date
        let keys: [PluginSigningKey]
    }
}
