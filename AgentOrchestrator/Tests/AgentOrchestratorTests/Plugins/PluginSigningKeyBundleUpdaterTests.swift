import Abstractions
import CryptoKit
import Foundation
import Testing

@testable import AgentOrchestrator

@Suite("PluginSigningKeyBundleUpdater Tests")
internal struct PluginSigningKeyBundleUpdaterTests {
    @Test("Signed bundle replaces signing keys")
    internal func signedBundleReplacesKeys() async throws {
        let context: Self.UpdateContext = makeContext()
        let rotatedKey: PluginSigningKey = makeSigningKey(
            id: "rotated",
            privateKey: Curve25519.Signing.PrivateKey()
        )
        let bundle: PluginSigningKeyBundle = try makeSignedBundle(
            keys: [rotatedKey],
            issuedAt: context.now,
            signerKeyId: context.signerKey.id,
            signerPrivateKey: context.signerPrivateKey
        )

        try await context.updater.apply(bundle: bundle)

        let snapshot: PluginTrustSnapshot = try await context.store.load()
        #expect(snapshot.signingKeys == [rotatedKey])
    }

    @Test("Unknown signing key is rejected")
    internal func unknownSigningKeyIsRejected() async throws {
        let now: Date = Date()
        let signerPrivateKey: Curve25519.Signing.PrivateKey = Curve25519.Signing.PrivateKey()
        let store: InMemoryPluginTrustStore = InMemoryPluginTrustStore()
        let updater: PluginSigningKeyBundleUpdater = makeUpdater(store: store, now: now)
        let key: PluginSigningKey = makeSigningKey(
            id: "new",
            privateKey: Curve25519.Signing.PrivateKey()
        )
        let bundle: PluginSigningKeyBundle = try makeSignedBundle(
            keys: [key],
            issuedAt: now,
            signerKeyId: "unknown",
            signerPrivateKey: signerPrivateKey
        )

        await #expect(throws: PluginSigningKeyBundleError.unknownKey) {
            try await updater.apply(bundle: bundle)
        }
    }

    @Test("Invalid bundle signature is rejected")
    internal func invalidSignatureIsRejected() async throws {
        let context: Self.UpdateContext = makeContext()
        let key: PluginSigningKey = makeSigningKey(
            id: "new",
            privateKey: Curve25519.Signing.PrivateKey()
        )
        let bundle: PluginSigningKeyBundle = PluginSigningKeyBundle(
            issuedAt: context.now,
            keys: [key],
            signature: "invalid",
            signatureKeyId: context.signerKey.id,
            signatureAlgorithm: .ed25519
        )

        await #expect(throws: PluginSigningKeyBundleError.signatureInvalid) {
            try await context.updater.apply(bundle: bundle)
        }
    }

    @Test("Expired signing key is rejected")
    internal func expiredSigningKeyIsRejected() async throws {
        let now: Date = Date()
        let context: Self.UpdateContext = makeContext(
            now: now,
            notAfter: now.addingTimeInterval(-60)
        )
        let key: PluginSigningKey = makeSigningKey(
            id: "new",
            privateKey: Curve25519.Signing.PrivateKey()
        )
        let bundle: PluginSigningKeyBundle = try makeSignedBundle(
            keys: [key],
            issuedAt: now,
            signerKeyId: context.signerKey.id,
            signerPrivateKey: context.signerPrivateKey
        )

        await #expect(throws: PluginSigningKeyBundleError.signatureExpired) {
            try await context.updater.apply(bundle: bundle)
        }
    }

    private func makeContext(
        now: Date = Date(),
        notAfter: Date? = nil
    ) -> UpdateContext {
        let signerPrivateKey: Curve25519.Signing.PrivateKey = Curve25519.Signing.PrivateKey()
        let signerKey: PluginSigningKey = makeSigningKey(
            id: "root",
            privateKey: signerPrivateKey,
            notAfter: notAfter
        )
        let store: InMemoryPluginTrustStore = InMemoryPluginTrustStore(
            snapshot: PluginTrustSnapshot(signingKeys: [signerKey])
        )
        let updater: PluginSigningKeyBundleUpdater = makeUpdater(store: store, now: now)
        return UpdateContext(
            now: now,
            store: store,
            updater: updater,
            signerKey: signerKey,
            signerPrivateKey: signerPrivateKey
        )
    }

    private func makeUpdater(
        store: InMemoryPluginTrustStore,
        now: Date
    ) -> PluginSigningKeyBundleUpdater {
        PluginSigningKeyBundleUpdater(store: store) { now }
    }

    private func makeSignedBundle(
        keys: [PluginSigningKey],
        issuedAt: Date,
        signerKeyId: String,
        signerPrivateKey: Curve25519.Signing.PrivateKey
    ) throws -> PluginSigningKeyBundle {
        let unsigned: PluginSigningKeyBundle = PluginSigningKeyBundle(
            issuedAt: issuedAt,
            keys: keys
        )
        guard let payload = unsigned.signaturePayload else {
            throw PluginSigningKeyBundleError.signatureInvalid
        }
        let signatureData: Data = try signerPrivateKey.signature(for: Data(payload.utf8))
        return PluginSigningKeyBundle(
            issuedAt: issuedAt,
            keys: keys,
            signature: signatureData.base64EncodedString(),
            signatureKeyId: signerKeyId,
            signatureAlgorithm: .ed25519
        )
    }

    private func makeSigningKey(
        id: String,
        privateKey: Curve25519.Signing.PrivateKey,
        notAfter: Date? = nil
    ) -> PluginSigningKey {
        PluginSigningKey(
            id: id,
            algorithm: .ed25519,
            publicKey: privateKey.publicKey.rawRepresentation.base64EncodedString(),
            notAfter: notAfter
        )
    }

    private struct UpdateContext {
        let now: Date
        let store: InMemoryPluginTrustStore
        let updater: PluginSigningKeyBundleUpdater
        let signerKey: PluginSigningKey
        let signerPrivateKey: Curve25519.Signing.PrivateKey
    }
}
