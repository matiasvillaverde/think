import Foundation
import Abstractions
import OSLog
import SwiftData

// MARK: - Database Configuration
public struct DatabaseConfiguration: Sendable {
    public let isStoredInMemoryOnly: Bool
    public let allowsSave: Bool
    public let ragFactory: RagFactory
    public let storeURL: URL?

    public init(
        isStoredInMemoryOnly: Bool,
        allowsSave: Bool,
        ragFactory: RagFactory,
        storeURL: URL? = nil
    ) {
        self.isStoredInMemoryOnly = isStoredInMemoryOnly
        self.allowsSave = allowsSave
        self.ragFactory = ragFactory
        self.storeURL = storeURL
    }

    public init(
        isStoredInMemoryOnly: Bool,
        allowsSave: Bool,
        ragFactory: RagFactory
    ) {
        self.init(
            isStoredInMemoryOnly: isStoredInMemoryOnly,
            allowsSave: allowsSave,
            ragFactory: ragFactory,
            storeURL: nil
        )
    }
}

extension Logger {
    static let database = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.app",
        category: "Database"
    )
}

extension OSSignposter {
    static let database = OSSignposter(subsystem: Bundle.main.bundleIdentifier ?? "com.app", category: "Database")
}
