import Testing
import Foundation
import SwiftData
@testable import Database
import AbstractionsTestUtilities
import Abstractions

@Suite("File Commands RAG Integration Tests")
struct FileCommandsRagTests {
    @Suite(.tags(.integration), .serialized)
    @MainActor
    struct RagOperationTests {
        @Test("RAG receives correct file data on creation")
        func verifyRagDataOnCreate() async throws {
            // Given
            let mockRag = MockRagging()
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: mockRag)
            )

            let database = try Database.new(configuration: config)
            try await addRequiredModels(database)
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

            let chat = try await database.read(ChatCommands.GetFirst())

            // Create a test file
            let testContent = "This is test content for RAG integration"
            let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("rag-test.txt")
            try testContent.write(to: fileURL, atomically: true, encoding: .utf8)

            // When
            try await database.write(FileCommands.Create(
                fileURL: fileURL,
                chatId: chat.id,
                database: database
            ))

            // Then
            try await Task.sleep(nanoseconds: 100_000_000)
            let lastCall = await mockRag.lastAddFileCall
            #expect(lastCall != nil)
            #expect(lastCall?.url.lastPathComponent == "rag-test.txt")

            // Cleanup
            try? FileManager.default.removeItem(at: fileURL)
        }

        @Test("RAG receives delete command when file is deleted")
        func verifyRagDeleteCommand() async throws {
            // Given
            let mockRag = MockRagging()
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: mockRag)
            )

            let database = try Database.new(configuration: config)
            try await addRequiredModels(database)
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

            let chat = try await database.read(ChatCommands.GetFirst())

            // Create and add a file
            let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("delete-test.txt")
            try "Content to delete".write(to: fileURL, atomically: true, encoding: .utf8)

            try await database.write(FileCommands.Create(
                fileURL: fileURL,
                chatId: chat.id,
                database: database
            ))

            // Get the created file
            let descriptor = FetchDescriptor<FileAttachment>()
            let files = try database.modelContainer.mainContext.fetch(descriptor)
            #expect(files.count == 1)
            let fileId = files.first!.id

            // When
            try await database.write(FileCommands.Delete(fileId: fileId))

            // Then
            try await Task.sleep(nanoseconds: 100_000_000)
            let deleteOperations = await mockRag.deleteIDCalls
            #expect(!deleteOperations.isEmpty)
            #expect(deleteOperations.contains { $0.id == fileId })

            // Cleanup
            try? FileManager.default.removeItem(at: fileURL)
        }

        @Test("RAG configuration matches chat settings")
        func verifyRagConfig() async throws {
            // Given
            let mockRag = MockRagging()
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: mockRag)
            )

            let database = try Database.new(configuration: config)
            try await addRequiredModels(database)
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

            let chat = try await database.read(ChatCommands.GetFirst())

            // Create a test file
            let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("config-test.txt")
            try "Configuration test content".write(to: fileURL, atomically: true, encoding: .utf8)

            // When
            try await database.write(FileCommands.Create(
                fileURL: fileURL,
                chatId: chat.id,
                database: database
            ))

            // Then
            // Verify RAG received the file
            try await Task.sleep(nanoseconds: 100_000_000)
            let lastCall = await mockRag.lastAddFileCall
            #expect(lastCall != nil)
            #expect(lastCall?.url.lastPathComponent == "config-test.txt")
            #expect(lastCall?.config.tokenUnit == .word)
            #expect(lastCall?.config.table == chat.generateTableName())
            #expect(lastCall?.config.chunking == .fileDefault)

            // Cleanup
            try? FileManager.default.removeItem(at: fileURL)
        }

        @Test("RAG receives correct file ID for deletion")
        func verifyRagFileId() async throws {
            // Given
            let mockRag = MockRagging()
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: mockRag)
            )

            let database = try Database.new(configuration: config)
            try await addRequiredModels(database)
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

            let chat = try await database.read(ChatCommands.GetFirst())

            // Create multiple files
            var fileIds: [UUID] = []
            for index in 1...3 {
                let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("multi-test-\(index).txt")
                try "Content \(index)".write(to: fileURL, atomically: true, encoding: .utf8)

                try await database.write(FileCommands.Create(
                    fileURL: fileURL,
                    chatId: chat.id,
                    database: database
                ))

                // Cleanup
                try? FileManager.default.removeItem(at: fileURL)
            }

            // Get all file IDs
            let descriptor = FetchDescriptor<FileAttachment>()
            let files = try database.modelContainer.mainContext.fetch(descriptor)
            fileIds = files.map { $0.id }
            #expect(fileIds.count == 3)

            // When - Delete the second file
            let fileToDelete = fileIds[1]
            try await database.write(FileCommands.Delete(fileId: fileToDelete))

            // Then
            try await Task.sleep(nanoseconds: 100_000_000)
            let deleteOperations = await mockRag.deleteIDCalls
            #expect(!deleteOperations.isEmpty)
            #expect(deleteOperations.contains { $0.id == fileToDelete })

            // Verify only one file was deleted
            let remainingDescriptor = FetchDescriptor<FileAttachment>()
            let remainingFiles = try database.modelContainer.mainContext.fetch(remainingDescriptor)
            #expect(remainingFiles.count == 2)
            #expect(!remainingFiles.map { $0.id }.contains(fileToDelete))
        }
    }
}

// MARK: - Helper Functions

private func addRequiredModels(_ database: Database) async throws {
    // Initialize default personality first
    try await database.write(PersonalityCommands.WriteDefault())
    
    // Add language models
    let languageModel = ModelDTO(
        type: .language,
        backend: .mlx,
        name: "test-llm",
        displayName: "Test LLM",
        displayDescription: "A test language model",
        skills: ["text-generation"],
        parameters: 100000,
        ramNeeded: 100.megabytes,
        size: 50.megabytes,
        locationHuggingface: "test/llm",
        version: 1
    )

    // Add image model
    let imageModel = ModelDTO(
        type: .diffusion,
        backend: .mlx,
        name: "test-image",
        displayName: "Test Image",
        displayDescription: "A test image model",
        skills: ["image-generation"],
        parameters: 50000,
        ramNeeded: 200.megabytes,
        size: 100.megabytes,
        locationHuggingface: "test/image",
        version: 1
    )

    try await database.write(ModelCommands.AddModels(modelDTOs: [languageModel, imageModel]))
}

// MARK: - Extensions

// MARK: - Potential Bugs Found
/*
1. Missing Validation:
   - No validation for maximum file size
   - No validation for allowed file types/extensions
   - No validation for duplicate file names in the same chat

2. State Management:
   - No cleanup mechanism if RAG processing fails midway

3. Progress Updates:
   - The 5% threshold for progress updates might miss important state changes
   - No handling of progress updates for already completed files
   - No handling of progress updates for failed files

5. Resource Management:
   - Security-scoped resource access is not handled in a try-defer block
   - No cleanup of temporary files if the creation process fails
   - No size check before loading file data into memory

6. Error Handling:
   - Limited error types in FileAttachment.Error
   - No specific handling for RAG-related errors
   - No retry mechanism for failed operations
*/
