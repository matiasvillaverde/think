import CryptoKit
import Foundation
import RemoteSession

internal protocol OpenClawSecretsStoring: Sendable {
    func getSharedToken(instanceId: UUID) async throws -> String?
    func setSharedToken(instanceId: UUID, token: String?) async throws

    func getDeviceToken(instanceId: UUID, role: String) async throws -> String?
    func setDeviceToken(instanceId: UUID, role: String, token: String?) async throws

    func deleteSecrets(instanceId: UUID) async throws
    func loadOrCreateDeviceIdentity(instanceId: UUID) async throws -> OpenClawDeviceIdentity
}

internal actor OpenClawKeychainSecretsStore: OpenClawSecretsStoring {
    private let storage: SecureStorageProtocol

    init(storage: SecureStorageProtocol = KeychainStorage(service: "com.think.openclaw")) {
        self.storage = storage
    }

    func getSharedToken(instanceId: UUID) async throws -> String? {
        try await getUTF8String(forKey: keySharedToken(instanceId))
    }

    func setSharedToken(instanceId: UUID, token: String?) async throws {
        let key: String = keySharedToken(instanceId)
        try await setUTF8String(token, forKey: key)
    }

    func getDeviceToken(instanceId: UUID, role: String) async throws -> String? {
        try await getUTF8String(forKey: keyDeviceToken(instanceId, role: role))
    }

    func setDeviceToken(instanceId: UUID, role: String, token: String?) async throws {
        let key: String = keyDeviceToken(instanceId, role: role)
        try await setUTF8String(token, forKey: key)
    }

    func deleteSecrets(instanceId: UUID) async throws {
        try await storage.delete(forKey: keySharedToken(instanceId))
        try await storage.delete(forKey: keyDevicePrivateKey(instanceId))

        // Role-scoped keys: clear default role only (we only use operator today).
        try await storage.delete(
            forKey: keyDeviceToken(instanceId, role: OpenClawDeviceAuth.defaultRole)
        )
    }

    func loadOrCreateDeviceIdentity(instanceId: UUID) async throws -> OpenClawDeviceIdentity {
        let key: String = keyDevicePrivateKey(instanceId)
        if let existing: Data = try await storage.retrieve(forKey: key) {
            let privateKey: Curve25519.Signing.PrivateKey =
                try Curve25519.Signing.PrivateKey(rawRepresentation: existing)
            return OpenClawDeviceIdentity(privateKey: privateKey)
        }

        let privateKey: Curve25519.Signing.PrivateKey = Curve25519.Signing.PrivateKey()
        try await storage.store(privateKey.rawRepresentation, forKey: key)
        return OpenClawDeviceIdentity(privateKey: privateKey)
    }

    // MARK: - Helpers

    private func getUTF8String(forKey key: String) async throws -> String? {
        guard let data: Data = try await storage.retrieve(forKey: key) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func setUTF8String(_ value: String?, forKey key: String) async throws {
        let trimmed: String? = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            guard let data: Data = trimmed.data(using: .utf8) else {
                return
            }
            try await storage.store(data, forKey: key)
            return
        }
        try await storage.delete(forKey: key)
    }

    private func keySharedToken(_ id: UUID) -> String {
        "openclaw.instance.\(id.uuidString).shared_token"
    }

    private func keyDeviceToken(_ id: UUID, role: String) -> String {
        let normalizedRole: String = role.trimmingCharacters(in: .whitespacesAndNewlines)
        return "openclaw.instance.\(id.uuidString).device_token.\(normalizedRole)"
    }

    private func keyDevicePrivateKey(_ id: UUID) -> String {
        "openclaw.instance.\(id.uuidString).device_private_key"
    }
}
