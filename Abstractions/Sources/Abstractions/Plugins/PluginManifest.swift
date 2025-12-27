import Foundation

/// Supported algorithms for plugin signature verification.
public enum PluginSignatureAlgorithm: String, Sendable, Codable, Equatable {
    case ed25519
}

/// Manifest for a plugin and its optional signature metadata.
public struct PluginManifest: Sendable, Codable, Equatable {
    public let id: String
    public let name: String
    public let version: String
    public let checksum: String?
    public let signature: String?
    public let signatureKeyId: String?
    public let signatureAlgorithm: PluginSignatureAlgorithm?
    public let sandboxed: Bool

    public init(
        id: String,
        name: String,
        version: String,
        checksum: String? = nil,
        signature: String? = nil,
        signatureKeyId: String? = nil,
        signatureAlgorithm: PluginSignatureAlgorithm? = nil,
        sandboxed: Bool = false
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.checksum = checksum
        self.signature = signature
        self.signatureKeyId = signatureKeyId
        self.signatureAlgorithm = signatureAlgorithm
        self.sandboxed = sandboxed
    }

    /// Canonical payload used for signature verification.
    public var signaturePayload: String? {
        guard let checksum else {
            return nil
        }
        return [id, version, checksum].joined(separator: "|")
    }
}

public enum PluginTrustLevel: String, Sendable, Codable, Equatable {
    case trusted
    case untrusted
    case requiresUserApproval = "requires_user_approval"
}

public enum PluginTrustReason: String, Sendable, Codable, Equatable {
    case signed
    case allowListed = "allow_listed"
    case sandboxed
    case revoked
    case checksumMismatch = "checksum_mismatch"
    case signatureInvalid = "signature_invalid"
    case signatureUnknownKey = "signature_unknown_key"
    case signatureExpired = "signature_expired"
    case signatureNotYetValid = "signature_not_yet_valid"
    case signatureRevoked = "signature_revoked"
    case unknown
}

public struct PluginTrustDecision: Sendable, Equatable, Codable {
    public let level: PluginTrustLevel
    public let reasons: [PluginTrustReason]

    public init(level: PluginTrustLevel, reasons: [PluginTrustReason]) {
        self.level = level
        self.reasons = reasons
    }
}

public struct PluginTrustRecord: Sendable, Equatable, Codable, Identifiable {
    public let id: String
    public let checksum: String?
    public let addedAt: Date

    public init(id: String, checksum: String?, addedAt: Date = Date()) {
        self.id = id
        self.checksum = checksum
        self.addedAt = addedAt
    }
}

/// A trusted signing key for plugin signatures.
public struct PluginSigningKey: Sendable, Codable, Equatable, Identifiable {
    public let id: String
    public let algorithm: PluginSignatureAlgorithm
    public let publicKey: String
    public let notBefore: Date?
    public let notAfter: Date?
    public let revokedAt: Date?

    public init(
        id: String,
        algorithm: PluginSignatureAlgorithm,
        publicKey: String,
        notBefore: Date? = nil,
        notAfter: Date? = nil,
        revokedAt: Date? = nil
    ) {
        self.id = id
        self.algorithm = algorithm
        self.publicKey = publicKey
        self.notBefore = notBefore
        self.notAfter = notAfter
        self.revokedAt = revokedAt
    }
}

public struct PluginTrustSnapshot: Sendable, Equatable, Codable {
    public var allowList: [PluginTrustRecord]
    public var denyList: Set<String>
    public var signingKeys: [PluginSigningKey]

    public init(
        allowList: [PluginTrustRecord] = [],
        denyList: Set<String> = [],
        signingKeys: [PluginSigningKey] = []
    ) {
        self.allowList = allowList
        self.denyList = denyList
        self.signingKeys = signingKeys
    }
}
