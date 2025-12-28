import Abstractions
import CryptoKit
import Foundation
import Testing

@testable import AgentOrchestrator

@Suite("PluginTrustEvaluator Tests")
internal struct PluginTrustEvaluatorTests {
    @Test("Allowlisted plugin with matching checksum is trusted")
    internal func allowlistedPluginIsTrusted() async throws {
        let store: InMemoryPluginTrustStore = InMemoryPluginTrustStore(
            snapshot: PluginTrustSnapshot(
                allowList: [PluginTrustRecord(id: "test.plugin", checksum: "abc123")]
            )
        )
        let evaluator: PluginTrustEvaluator = PluginTrustEvaluator(store: store)

        let decision: PluginTrustDecision = try await evaluator.evaluate(
            manifest: makeManifest(id: "test.plugin", checksum: "abc123")
        )

        #expect(decision.level == .trusted)
        #expect(decision.reasons.contains(.allowListed))
    }

    @Test("Checksum mismatch results in untrusted decision")
    internal func checksumMismatchIsUntrusted() async throws {
        let store: InMemoryPluginTrustStore = InMemoryPluginTrustStore(
            snapshot: PluginTrustSnapshot(
                allowList: [PluginTrustRecord(id: "test.plugin", checksum: "abc123")]
            )
        )
        let evaluator: PluginTrustEvaluator = PluginTrustEvaluator(store: store)

        let decision: PluginTrustDecision = try await evaluator.evaluate(
            manifest: makeManifest(id: "test.plugin", checksum: "different")
        )

        #expect(decision.level == .untrusted)
        #expect(decision.reasons.contains(.checksumMismatch))
    }

    @Test("Revoked plugin is untrusted even if signed")
    internal func revokedPluginIsUntrusted() async throws {
        let store: InMemoryPluginTrustStore = InMemoryPluginTrustStore(
            snapshot: PluginTrustSnapshot(
                denyList: ["revoked.plugin"]
            )
        )
        let evaluator: PluginTrustEvaluator = PluginTrustEvaluator(store: store)

        let decision: PluginTrustDecision = try await evaluator.evaluate(
            manifest: makeManifest(
                id: "revoked.plugin",
                name: "Revoked",
                checksum: nil,
                signature: "signature"
            )
        )

        #expect(decision.level == .untrusted)
        #expect(decision.reasons.contains(.revoked))
    }

    @Test("Allow and revoke update trust store")
    internal func allowAndRevokeUpdatesStore() async throws {
        let store: InMemoryPluginTrustStore = InMemoryPluginTrustStore()
        let evaluator: PluginTrustEvaluator = PluginTrustEvaluator(store: store)

        try await evaluator.allow(pluginId: "dynamic.plugin", checksum: "123")
        let decision: PluginTrustDecision = try await evaluator.evaluate(
            manifest: makeManifest(id: "dynamic.plugin", name: "Dynamic", checksum: "123")
        )
        #expect(decision.level == .trusted)

        try await evaluator.revoke(pluginId: "dynamic.plugin")
        let revokedDecision: PluginTrustDecision = try await evaluator.evaluate(
            manifest: makeManifest(id: "dynamic.plugin", name: "Dynamic", checksum: "123")
        )
        #expect(revokedDecision.level == .untrusted)
        #expect(revokedDecision.reasons.contains(.revoked))
    }

    @Test("Signed plugin with trusted key is trusted")
    internal func signedPluginWithTrustedKeyIsTrusted() async throws {
        let keyId: String = "key-1"
        let privateKey: Curve25519.Signing.PrivateKey = Curve25519.Signing.PrivateKey()
        let signingKey: PluginSigningKey = makeSigningKey(
            id: keyId,
            privateKey: privateKey
        )
        let store: InMemoryPluginTrustStore = InMemoryPluginTrustStore(
            snapshot: PluginTrustSnapshot(signingKeys: [signingKey])
        )
        let evaluator: PluginTrustEvaluator = PluginTrustEvaluator(store: store)
        let manifest: PluginManifest = try makeSignedManifest(
            id: "signed.plugin",
            checksum: "abc123",
            keyId: keyId,
            privateKey: privateKey
        )

        let decision: PluginTrustDecision = try await evaluator.evaluate(manifest: manifest)

        #expect(decision.level == .trusted)
        #expect(decision.reasons.contains(.signed))
    }

    @Test("Signed plugin with unknown key requires approval")
    internal func signedPluginWithUnknownKeyRequiresApproval() async throws {
        let privateKey: Curve25519.Signing.PrivateKey = Curve25519.Signing.PrivateKey()
        let store: InMemoryPluginTrustStore = InMemoryPluginTrustStore()
        let evaluator: PluginTrustEvaluator = PluginTrustEvaluator(store: store)
        let manifest: PluginManifest = try makeSignedManifest(
            id: "unknown.plugin",
            checksum: "abc123",
            keyId: "missing-key",
            privateKey: privateKey
        )

        let decision: PluginTrustDecision = try await evaluator.evaluate(manifest: manifest)

        #expect(decision.level == .requiresUserApproval)
        #expect(decision.reasons.contains(.signatureUnknownKey))
    }

    @Test("Expired signing key requires approval")
    internal func expiredSigningKeyRequiresApproval() async throws {
        let now: Date = Date(timeIntervalSince1970: 1_700_000_000)
        let privateKey: Curve25519.Signing.PrivateKey = Curve25519.Signing.PrivateKey()
        let expiredKey: PluginSigningKey = makeExpiredKey(privateKey: privateKey, now: now)
        let store: InMemoryPluginTrustStore = makeStore(signingKeys: [expiredKey])
        let evaluator: PluginTrustEvaluator = PluginTrustEvaluator(store: store) { now }
        let manifest: PluginManifest = try makeSignedManifest(
            id: "expired.plugin",
            checksum: "abc123",
            keyId: "expired-key",
            privateKey: privateKey
        )

        let decision: PluginTrustDecision = try await evaluator.evaluate(manifest: manifest)

        #expect(decision.level == .requiresUserApproval)
        #expect(decision.reasons.contains(.signatureExpired))
    }

    @Test("Invalid signature is untrusted")
    internal func invalidSignatureIsUntrusted() async throws {
        let keyId: String = "key-2"
        let privateKey: Curve25519.Signing.PrivateKey = Curve25519.Signing.PrivateKey()
        let signingKey: PluginSigningKey = makeSigningKey(id: keyId, privateKey: privateKey)
        let store: InMemoryPluginTrustStore = makeStore(signingKeys: [signingKey])
        let evaluator: PluginTrustEvaluator = PluginTrustEvaluator(store: store)
        let manifest: PluginManifest = makeManifest(
            id: "invalid.plugin",
            checksum: "abc123",
            signature: "invalid-signature",
            signatureKeyId: keyId,
            signatureAlgorithm: .ed25519
        )

        let decision: PluginTrustDecision = try await evaluator.evaluate(manifest: manifest)

        #expect(decision.level == .untrusted)
        #expect(decision.reasons.contains(.signatureInvalid))
    }

    private func makeManifest(
        id: String,
        name: String = "Test",
        version: String = "1.0.0",
        checksum: String? = nil,
        signature: String? = nil,
        signatureKeyId: String? = nil,
        signatureAlgorithm: PluginSignatureAlgorithm? = nil
    ) -> PluginManifest {
        PluginManifest(
            id: id,
            name: name,
            version: version,
            checksum: checksum,
            signature: signature,
            signatureKeyId: signatureKeyId,
            signatureAlgorithm: signatureAlgorithm
        )
    }

    private func makeSignedManifest(
        id: String,
        checksum: String,
        keyId: String,
        privateKey: Curve25519.Signing.PrivateKey
    ) throws -> PluginManifest {
        let manifest: PluginManifest = makeManifest(
            id: id,
            checksum: checksum,
            signatureKeyId: keyId,
            signatureAlgorithm: .ed25519
        )
        guard let payload = manifest.signaturePayload else {
            throw TestError.invalidPayload
        }
        let signatureData: Data = try privateKey.signature(for: Data(payload.utf8))
        return makeManifest(
            id: id,
            checksum: checksum,
            signature: signatureData.base64EncodedString(),
            signatureKeyId: keyId,
            signatureAlgorithm: .ed25519
        )
    }

    private enum TestError: Error {
        case invalidPayload
    }

    private func makeStore(
        signingKeys: [PluginSigningKey]
    ) -> InMemoryPluginTrustStore {
        InMemoryPluginTrustStore(
            snapshot: PluginTrustSnapshot(signingKeys: signingKeys)
        )
    }

    private func makeExpiredKey(
        privateKey: Curve25519.Signing.PrivateKey,
        now: Date
    ) -> PluginSigningKey {
        makeSigningKey(
            id: "expired-key",
            privateKey: privateKey,
            notAfter: now.addingTimeInterval(-60)
        )
    }

    private func makeSigningKey(
        id: String,
        privateKey: Curve25519.Signing.PrivateKey,
        notBefore: Date? = nil,
        notAfter: Date? = nil,
        revokedAt: Date? = nil
    ) -> PluginSigningKey {
        let publicKeyData: Data = privateKey.publicKey.rawRepresentation
        return PluginSigningKey(
            id: id,
            algorithm: .ed25519,
            publicKey: publicKeyData.base64EncodedString(),
            notBefore: notBefore,
            notAfter: notAfter,
            revokedAt: revokedAt
        )
    }
}
