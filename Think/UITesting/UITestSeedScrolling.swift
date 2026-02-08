import Abstractions
import Database
import Foundation

internal enum UITestSeedScrolling {
    internal static func seedHistory(
        database: DatabaseProtocol,
        chatId: UUID,
        messageCount: Int
    ) async throws {
        for index in 0..<messageCount {
            let messageId: UUID = try await database.write(
                MessageCommands.Create(
                    chatId: chatId,
                    userInput: "History message \(index + 1)",
                    isDeepThinker: false
                )
            )

            let output = ProcessedOutput(
                channels: [
                    ChannelMessage(
                        id: UUID(),
                        type: .final,
                        content: "History response \(index + 1).",
                        order: 0,
                        isComplete: true
                    )
                ]
            )

            _ = try await database.write(
                MessageCommands.UpdateProcessedOutput(messageId: messageId, processedOutput: output)
            )
        }
    }

    internal static func seedStreamingScrollMessage(database: DatabaseProtocol, chatId: UUID) async throws {
        let messageId: UUID = try await database.write(
            MessageCommands.Create(chatId: chatId, userInput: "Auto-scroll streaming test", isDeepThinker: false)
        )

        try await writeScrollStreamingUpdate(
            database: database,
            messageId: messageId,
            step: 0,
            isComplete: false
        )

        // Keep streaming updates running while UITests are executing.
        Task(priority: .userInitiated) {
            for stepIndex in 1...18 {
                _ = try? await writeScrollStreamingUpdate(
                    database: database,
                    messageId: messageId,
                    step: stepIndex,
                    isComplete: false
                )
                try? await Task.sleep(for: .milliseconds(140))
            }

            _ = try? await writeScrollStreamingComplete(
                database: database,
                messageId: messageId
            )
        }
    }

    private static func writeScrollStreamingUpdate(
        database: DatabaseProtocol,
        messageId: UUID,
        step: Int,
        isComplete: Bool
    ) async throws {
        let ids = UITestIDs.shared
        let growth: String = String(repeating: "x", count: step * 80)
        let output = ProcessedOutput(
            channels: [
                ChannelMessage(
                    id: ids.scrollStreamingFinalChannelId,
                    type: .final,
                    content: "AUTO_SCROLL_STREAM step \(step) \(growth)",
                    order: 0,
                    isComplete: isComplete
                )
            ]
        )

        _ = try await database.write(
            MessageCommands.UpdateProcessedOutput(messageId: messageId, processedOutput: output)
        )
    }

    private static func writeScrollStreamingComplete(
        database: DatabaseProtocol,
        messageId: UUID
    ) async throws {
        let ids = UITestIDs.shared
        let output = ProcessedOutput(
            channels: [
                ChannelMessage(
                    id: ids.scrollStreamingFinalChannelId,
                    type: .final,
                    content: "AUTO_SCROLL_STREAM complete",
                    order: 0,
                    isComplete: true
                )
            ]
        )
        _ = try await database.write(
            MessageCommands.UpdateProcessedOutput(messageId: messageId, processedOutput: output)
        )
    }
}
