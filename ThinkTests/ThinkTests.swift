import Testing
@testable import Database
import AbstractionsTestUtilities
import Factories

struct ThinkTests {

    @Test("Clear in-memory database")
    func emptyDB() async throws {
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await database.execute(AppCommands.DeleteAll())
    }
}
