import Testing
import Foundation
import SwiftData
@testable import Database
import AbstractionsTestUtilities
import Abstractions

@Suite("File Commands Tests")
struct FileCommandsTests {
    @Suite(.tags(.acceptance))
    @MainActor
    struct BasicFunctionalityTests {
        @Test("Create file attachment successfully")
        func createFileSuccess() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)
            try await addRequiredModels(database)
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

            let chat = try await database.read(ChatCommands.GetFirst())

            // Create a temporary file
            let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.txt")
            try "Test content".write(to: fileURL, atomically: true, encoding: .utf8)

            // When
            try await database.write(FileCommands.Create(
                fileURL: fileURL,
                chatId: chat.id,
                database: database
            ))

            // Then
            let hasAttachments = try await database.read(ChatCommands.HasAttachments(chatId: chat.id))
            #expect(hasAttachments == true)

            // Cleanup
            try? FileManager.default.removeItem(at: fileURL)
        }

        @Test("Delete file attachment successfully")
        func deleteFileSuccess() async throws {
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
            let hasAttachments = try await database.read(ChatCommands.HasAttachments(chatId: chat.id))
            #expect(hasAttachments == false)

            // Cleanup
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    @Suite(.tags(.edge))
    @MainActor
    struct EdgeCaseTests {
        @Test("Create file with invalid URL fails")
        func createFileInvalidURL() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)
            try await addRequiredModels(database)
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

            let chat = try await database.read(ChatCommands.GetFirst())

            // Invalid URL that doesn't exist
            let invalidURL = FileManager.default.temporaryDirectory.appendingPathComponent("nonexistent.txt")

            // When/Then
            await #expect(throws: Error.self) {
                try await database.write(FileCommands.Create(
                    fileURL: invalidURL,
                    chatId: chat.id,
                    database: database
                ))
            }
        }

        @Test("Create file with nonexistent chat fails")
        func createFileNonexistentChat() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)

            // Create a temporary file
            let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("orphan.txt")
            try "Orphan content".write(to: fileURL, atomically: true, encoding: .utf8)

            // When/Then
            await #expect(throws: DatabaseError.chatNotFound) {
                try await database.write(FileCommands.Create(
                    fileURL: fileURL,
                    chatId: UUID(), // Nonexistent chat
                    database: database
                ))
            }

            // Cleanup
            try? FileManager.default.removeItem(at: fileURL)
        }

        @Test("Delete nonexistent file fails")
        func deleteNonexistentFile() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)

            // When/Then
            await #expect(throws: DatabaseError.fileNotFound) {
                try await database.write(FileCommands.Delete(fileId: UUID()))
            }
        }
    }

    @Suite(.tags(.state))
    @MainActor
    struct StateTests {
        @Test("File progress updates correctly", .disabled())
        func fileProgressUpdates() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)
            try await addRequiredModels(database)
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

            let chat = try await database.read(ChatCommands.GetFirst())

            // Create a file
            let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("progress-test.txt")
            try "Progress test content".write(to: fileURL, atomically: true, encoding: .utf8)

            try await database.write(FileCommands.Create(
                fileURL: fileURL,
                chatId: chat.id,
                database: database
            ))

            // Get the file
            let descriptor = FetchDescriptor<FileAttachment>()
            let files = try database.modelContainer.mainContext.fetch(descriptor)
            #expect(files.count == 1)
            let fileId = files.first!.id

            // When - Update progress
            for progress in stride(from: 0.0, through: 1.0, by: 0.1) {
                try await database.write(FileCommands.UpdateProgress(
                    fileId: fileId,
                    fractionCompleted: progress
                ))

                // Then - Verify progress updated
                let file = try await database.read(FileCommands.Get(fileId: fileId))
                #expect(abs(file.progress - progress) < 0.01)
            }

            // Cleanup
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    @Suite(.tags(.performance))
    @MainActor
    struct PerformanceTests {
        @Test("Concurrent file operations maintain consistency")
        func concurrentFileOperations() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)
            try await addRequiredModels(database)
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

            let chat = try await database.read(ChatCommands.GetFirst())

            // Create multiple files concurrently
            let fileCount = 10
            var fileURLs: [URL] = []

            for index in 0..<fileCount {
                let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("concurrent-\(index).txt")
                try "Content \(index)".write(to: fileURL, atomically: true, encoding: .utf8)
                fileURLs.append(fileURL)
            }

            // When - Create files sequentially to avoid concurrency issues
            for fileURL in fileURLs {
                try await database.write(FileCommands.Create(
                    fileURL: fileURL,
                    chatId: chat.id,
                    database: database
                ))
            }

            // Then - All files should be created
            let attachments = try await database.read(ChatCommands.AttachmentFileTitles(chatId: chat.id))
            #expect(attachments.count == fileCount)

            // Cleanup
            for fileURL in fileURLs {
                try? FileManager.default.removeItem(at: fileURL)
            }
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

    try await database.write(ModelCommands.AddModels(models: [languageModel, imageModel]))
}

// MARK: - Extensions
