import Abstractions
import Database
import Foundation

internal enum UITestSeed {
    internal static func run(database: DatabaseProtocol) async throws {
        _ = try await database.execute(AppCommands.Initialize())

        let personalityId: UUID = try await database.write(PersonalityCommands.WriteDefault())
        try await UITestSeedModels.ensureLanguageModel(database: database)

        let chatId: UUID = try await database.write(ChatCommands.Create(personality: personalityId))

        // Ensure the message list is scrollable, then start a long-running streaming update on the
        // last message so UITests can validate pinned-to-bottom behavior.
        try await UITestSeedScrolling.seedHistory(database: database, chatId: chatId, messageCount: 10)
        try await UITestSeedMessages.seedSecondMessage(database: database, chatId: chatId)
        try await UITestSeedMessages.seedFirstMessage(database: database, chatId: chatId)
        try await UITestSeedScrolling.seedStreamingScrollMessage(database: database, chatId: chatId)
    }
}
