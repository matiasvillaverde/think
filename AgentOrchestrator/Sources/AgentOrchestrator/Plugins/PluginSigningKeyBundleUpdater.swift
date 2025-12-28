import Abstractions
import CryptoKit
import Foundation
import OSLog

/// Applies signed plugin key bundles to the trust store.
public final actor PluginSigningKeyBundleUpdater: PluginSigningKeyBundleUpdating {
    private static let logger: Logger = Logger(
        subsystem: "AgentOrchestrator",
        category: "PluginSigningKeyBundleUpdater"
    )

    private let store: PluginTrustStoring
    private let nowProvider: () -> Date

    private struct SignatureContext {
        let signature: String
        let payload: String
        let keyId: String
        let algorithm: PluginSignatureAlgorithm
    }

    public init(
        store: PluginTrustStoring,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.nowProvider = nowProvider
    }

    public func apply(bundle: PluginSigningKeyBundle) async throws {
        let snapshot: PluginTrustSnapshot = try await store.load()
        try Self.verify(bundle: bundle, snapshot: snapshot, now: nowProvider())

        var updated: PluginTrustSnapshot = snapshot
        updated.signingKeys = Self.deduplicatedKeys(bundle.keys)
        try await store.save(updated)
    }

    private static func verify(
        bundle: PluginSigningKeyBundle,
        snapshot: PluginTrustSnapshot,
        now: Date
    ) throws {
        let context: SignatureContext = try resolveContext(bundle: bundle)
        let key: PluginSigningKey = try resolveKey(context: context, snapshot: snapshot)
        try validateKey(key, now: now)
        guard verifySignature(signature: context.signature, payload: context.payload, key: key) else {
            throw PluginSigningKeyBundleError.signatureInvalid
        }
    }

    private static func resolveContext(
        bundle: PluginSigningKeyBundle
    ) throws -> SignatureContext {
        let signature: String = bundle.signature?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ) ?? ""
        guard !signature.isEmpty else {
            throw PluginSigningKeyBundleError.missingSignature
        }
        guard let keyId = bundle.signatureKeyId,
            let algorithm = bundle.signatureAlgorithm,
            let payload = bundle.signaturePayload else {
            throw PluginSigningKeyBundleError.missingSignature
        }
        return SignatureContext(
            signature: signature,
            payload: payload,
            keyId: keyId,
            algorithm: algorithm
        )
    }

    private static func resolveKey(
        context: SignatureContext,
        snapshot: PluginTrustSnapshot
    ) throws -> PluginSigningKey {
        guard let key = snapshot.signingKeys.first(where: { key in
            key.id == context.keyId && key.algorithm == context.algorithm
        }) else {
            throw PluginSigningKeyBundleError.unknownKey
        }
        return key
    }

    private static func validateKey(
        _ key: PluginSigningKey,
        now: Date
    ) throws {
        if let revokedAt = key.revokedAt, revokedAt <= now {
            throw PluginSigningKeyBundleError.signatureRevoked
        }
        if let notBefore = key.notBefore, now < notBefore {
            throw PluginSigningKeyBundleError.signatureNotYetValid
        }
        if let notAfter = key.notAfter, now > notAfter {
            throw PluginSigningKeyBundleError.signatureExpired
        }
    }

    private static func verifySignature(
        signature: String,
        payload: String,
        key: PluginSigningKey
    ) -> Bool {
        guard let signatureData: Data = Data(base64Encoded: signature),
            let payloadData: Data = payload.data(using: .utf8),
            let publicKeyData: Data = Data(base64Encoded: key.publicKey) else {
            return false
        }

        switch key.algorithm {
        case .ed25519:
            do {
                let publicKey: Curve25519.Signing.PublicKey = try Curve25519.Signing.PublicKey(
                    rawRepresentation: publicKeyData
                )
                return publicKey.isValidSignature(signatureData, for: payloadData)
            } catch {
                Self.logger.warning(
                    "Failed to decode bundle signing key: \(error.localizedDescription)"
                )
                return false
            }
        }
    }

    private static func deduplicatedKeys(_ keys: [PluginSigningKey]) -> [PluginSigningKey] {
        var seen: Set<String> = []
        var ordered: [PluginSigningKey] = []
        for key in keys where seen.insert(key.id).inserted {
            ordered.append(key)
        }
        return ordered
    }
}
