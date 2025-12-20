import Foundation
import Testing
import SwiftData
import Abstractions
@testable import Database

extension DatabaseConfiguration {
    static func mock(
        isStoredInMemoryOnly: Bool = true,
        allowsSave: Bool = true,
        ragFactory: RagFactory
    ) -> DatabaseConfiguration {
        DatabaseConfiguration(
            isStoredInMemoryOnly: isStoredInMemoryOnly,
            allowsSave: allowsSave,
            ragFactory: ragFactory
        )
    }
}

@MainActor
func waitForStatus(_ database: Database, expectedStatus: DatabaseStatus, timeout: TimeInterval = 0.3) async throws {
    let start = ProcessInfo.processInfo.systemUptime

    while true {
        switch (database.status, expectedStatus) {
        case (.ready, .ready),
             (.partiallyReady, .partiallyReady),
             (.failed, .failed):
            return
        case (.failed(let error), _):
            throw error
        default:
            if ProcessInfo.processInfo.systemUptime - start > timeout {
                throw DatabaseError.timeout
            }
            try await Task.sleep(nanoseconds: 200_000_000) // 0.1 second
        }
    }
}
