import Foundation
import RemoteSession

actor OpenClawSecureStorageProviderActor {
    private var factory: @Sendable () -> SecureStorageProtocol

    init(factory: @escaping @Sendable () -> SecureStorageProtocol) {
        self.factory = factory
    }

    func storage() -> SecureStorageProtocol {
        factory()
    }

    func setFactory(_ factory: @escaping @Sendable () -> SecureStorageProtocol) {
        self.factory = factory
    }

    func getFactory() -> (@Sendable () -> SecureStorageProtocol) {
        factory
    }
}

enum OpenClawSecureStorageProvider {
    private static let shared: OpenClawSecureStorageProviderActor =
        OpenClawSecureStorageProviderActor(
            factory: {
                KeychainStorage(service: "com.think.openclaw")
            }
        )

    static func storage() async -> SecureStorageProtocol {
        await shared.storage()
    }

    static func setFactory(
        _ factory: @escaping @Sendable () -> SecureStorageProtocol
    ) async {
        await shared.setFactory(factory)
    }

    static func getFactory() async -> (@Sendable () -> SecureStorageProtocol) {
        await shared.getFactory()
    }

    static func withFactory<T>(
        _ factory: @escaping @Sendable () -> SecureStorageProtocol,
        operation: () async throws -> T
    ) async rethrows -> T {
        let previous = await getFactory()
        await setFactory(factory)
        defer {
            Task {
                await setFactory(previous)
            }
        }
        return try await operation()
    }
}
