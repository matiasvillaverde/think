import Foundation
import Testing
@testable import Abstractions

@Suite("RAG Table Naming")
struct RagTableNameTests {
    @Test("Chat table name uses t_ prefix and normalized UUID")
    func testChatTableName() throws {
        let chatId = try #require(UUID(uuidString: "E13B17D0-3ACB-4C2E-A6D9-71AB2B5F5A49"))

        let tableName = RagTableName.chatTableName(chatId: chatId)

        #expect(tableName == "t_E13B17D0_3ACB_4C2E_A6D9_71AB2B5F5A49")
    }
}
