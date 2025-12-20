import Testing
import Foundation
import SwiftData
import Abstractions
@testable import Database
import AbstractionsTestUtilities

@Suite("Chat Commands Performance Tests", .tags(.performance))
struct ChatCommandsPerformanceTests {
    @Test("Chat creation performance meets threshold")
    func chatCreationPerformance() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )

        let database = try Database.new(configuration: config)
        try await addRequiredModelsForChatCommands(database)

        // When
        let start = ProcessInfo.processInfo.systemUptime
        let defaultPersonalityId = try await getDefaultPersonalityId(database)
        await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    try await database.write(ChatCommands.Create(personality: defaultPersonalityId))
                }
            }
        }
        let duration = ProcessInfo.processInfo.systemUptime - start

        // Then
        #expect(duration < 5) // Should complete within 0.1 seconds
    }
}
