import Abstractions
import CryptoKit
import Foundation

public final actor PluginTrustEvaluator: PluginTrustEvaluating {
    private let store: PluginTrustStoring
    private let nowProvider: () -> Date

    private struct SignatureContext {
        let signature: String
        let payload: String
        let keyId: String
        let algorithm: PluginSignatureAlgorithm
    }

    private enum SignatureContextDecision {
        case noSignature
        case invalid
        case context(SignatureContext)
    }

    public init(
        store: PluginTrustStoring,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.nowProvider = nowProvider
    }

    public func evaluate(manifest: PluginManifest) async throws -> PluginTrustDecision {
        let snapshot: PluginTrustSnapshot = try await store.load()
        return Self.evaluate(
            manifest: manifest,
            snapshot: snapshot,
            now: nowProvider()
        )
    }

    public func allow(pluginId: String, checksum: String?) async throws {
        var snapshot: PluginTrustSnapshot = try await store.load()
        snapshot.denyList.remove(pluginId)
        snapshot.allowList.removeAll { $0.id == pluginId }
        snapshot.allowList.append(PluginTrustRecord(id: pluginId, checksum: checksum))
        try await store.save(snapshot)
    }

    public func revoke(pluginId: String) async throws {
        var snapshot: PluginTrustSnapshot = try await store.load()
        snapshot.allowList.removeAll { $0.id == pluginId }
        snapshot.denyList.insert(pluginId)
        try await store.save(snapshot)
    }

    private static func evaluate(
        manifest: PluginManifest,
        snapshot: PluginTrustSnapshot,
        now: Date
    ) -> PluginTrustDecision {
        if snapshot.denyList.contains(manifest.id) {
            return PluginTrustDecision(level: .untrusted, reasons: [.revoked])
        }
        if let signatureDecision = signatureDecision(manifest: manifest, snapshot: snapshot, now: now) {
            return resolvedSignatureDecision(signatureDecision, manifest: manifest, snapshot: snapshot)
        }
        if let allowListDecision = evaluateAllowList(manifest: manifest, snapshot: snapshot) {
            return allowListDecision
        }
        if manifest.sandboxed {
            return PluginTrustDecision(level: .trusted, reasons: [.sandboxed])
        }
        return PluginTrustDecision(level: .requiresUserApproval, reasons: [.unknown])
    }

    private static func resolvedSignatureDecision(
        _ decision: PluginTrustDecision,
        manifest: PluginManifest,
        snapshot: PluginTrustSnapshot
    ) -> PluginTrustDecision {
        guard decision.level == .requiresUserApproval else {
            return decision
        }
        return evaluateAllowList(manifest: manifest, snapshot: snapshot) ?? decision
    }

    private static func evaluateAllowList(
        manifest: PluginManifest,
        snapshot: PluginTrustSnapshot
    ) -> PluginTrustDecision? {
        guard let record = snapshot.allowList.first(where: { $0.id == manifest.id }) else {
            return nil
        }

        if let expected = record.checksum, let actual = manifest.checksum, expected != actual {
            return PluginTrustDecision(level: .untrusted, reasons: [.checksumMismatch])
        }

        return PluginTrustDecision(level: .trusted, reasons: [.allowListed])
    }

    private static func signatureDecision(
        manifest: PluginManifest,
        snapshot: PluginTrustSnapshot,
        now: Date
    ) -> PluginTrustDecision? {
        switch resolveSignatureContext(for: manifest) {
        case .noSignature:
            return nil

        case .invalid:
            return PluginTrustDecision(level: .untrusted, reasons: [.signatureInvalid])

        case .context(let context):
            return evaluateSignatureContext(context, snapshot: snapshot, now: now)
        }
    }

    private static func resolveSignatureContext(
        for manifest: PluginManifest
    ) -> SignatureContextDecision {
        let signature: String = manifest.signature?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if signature.isEmpty {
            return .noSignature
        }
        guard let keyId = manifest.signatureKeyId else {
            return .invalid
        }
        guard let algorithm = manifest.signatureAlgorithm else {
            return .invalid
        }
        guard let payload = manifest.signaturePayload else {
            return .invalid
        }
        let context: SignatureContext = SignatureContext(
            signature: signature,
            payload: payload,
            keyId: keyId,
            algorithm: algorithm
        )
        return .context(context)
    }

    private static func evaluateSignatureContext(
        _ context: SignatureContext,
        snapshot: PluginTrustSnapshot,
        now: Date
    ) -> PluginTrustDecision {
        guard let key = signingKey(for: context, snapshot: snapshot) else {
            return PluginTrustDecision(level: .requiresUserApproval, reasons: [.signatureUnknownKey])
        }
        if let validityDecision = signingKeyDecision(key, now: now) {
            return validityDecision
        }
        let isValid: Bool = verifySignature(
            signature: context.signature,
            payload: context.payload,
            key: key
        )
        if isValid {
            return PluginTrustDecision(level: .trusted, reasons: [.signed])
        }
        return PluginTrustDecision(level: .untrusted, reasons: [.signatureInvalid])
    }

    private static func signingKey(
        for context: SignatureContext,
        snapshot: PluginTrustSnapshot
    ) -> PluginSigningKey? {
        snapshot.signingKeys.first { key in
            key.id == context.keyId && key.algorithm == context.algorithm
        }
    }

    private static func signingKeyDecision(
        _ key: PluginSigningKey,
        now: Date
    ) -> PluginTrustDecision? {
        if let revokedAt = key.revokedAt, revokedAt <= now {
            return PluginTrustDecision(level: .untrusted, reasons: [.signatureRevoked])
        }
        if let notBefore = key.notBefore, now < notBefore {
            return PluginTrustDecision(level: .requiresUserApproval, reasons: [.signatureNotYetValid])
        }
        if let notAfter = key.notAfter, now > notAfter {
            return PluginTrustDecision(level: .requiresUserApproval, reasons: [.signatureExpired])
        }
        return nil
    }

    private static func verifySignature(
        signature: String,
        payload: String,
        key: PluginSigningKey
    ) -> Bool {
        guard let signatureData: Data = Data(base64Encoded: signature) else {
            return false
        }
        guard let payloadData: Data = payload.data(using: .utf8) else {
            return false
        }
        guard let publicKeyData: Data = Data(base64Encoded: key.publicKey) else {
            return false
        }

        switch key.algorithm {
        case .ed25519:
            do {
                let publicKey: Curve25519.Signing.PublicKey =
                    try Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)
                return publicKey.isValidSignature(signatureData, for: payloadData)
            } catch {
                return false
            }
        }
    }
}
