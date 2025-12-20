import Testing
@testable import Database
import Factories

struct ThinkTests {

    @Test(.disabled())
    func emptyDB() async throws {
        try await Database.instance(configuration: .default).execute(AppCommands.DeleteAll())
    }
}
