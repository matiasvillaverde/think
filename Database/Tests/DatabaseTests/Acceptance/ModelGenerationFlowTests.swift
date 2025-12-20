import Testing
import Foundation
import SwiftData
@testable import Database
import AbstractionsTestUtilities
import Abstractions

// MARK: - Helper Functions

private func addRequiredModelsForFileTests(_ database: Database) async throws {
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
        ramNeeded: 100_000_000,
        size: 50_000_000,
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
        ramNeeded: 200_000_000,
        size: 100_000_000,
        locationHuggingface: "test/image",
        version: 1
    )

    try await database.write(ModelCommands.AddModels(models: [languageModel, imageModel]))
}

@Suite("File Handling and RAG Integration Tests")
struct FileHandlingRagTests {
    @Test("Complex file handling with RAG integration")
    @MainActor
    func complexFileHandling() async throws {
        // Given
        let mockRag = MockRagging()
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: mockRag)
        )

        let database = try Database.new(configuration: config)
        try await addRequiredModelsForFileTests(database)

        // Create chat for file testing
        let defaultPersonalityId = try await getDefaultPersonalityId(database)
        try await database.write(ChatCommands.Create(personality: defaultPersonalityId))
        let chat = try await database.read(ChatCommands.GetFirst())

        // Create files of different types
        let fileTypes = [
            ("document.txt", "Text document content"),
            ("data.json", "{\"key\": \"value\"}"),
            ("config.yaml", "setting: value"),
            ("report.md", "# Report heading")
        ]

        var fileURLs: [URL] = []

        // Add files and verify RAG integration
        for (filename, content) in fileTypes {
            let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            fileURLs.append(fileURL)

            try await database.write(FileCommands.Create(
                fileURL: fileURL,
                chatId: chat.id,
                database: database
            ))

            // Verify RAG received file
            try await Task.sleep(nanoseconds: 1_000_000_000)
            let lastCall = await mockRag.lastAddFileCall
            #expect(lastCall != nil)
            #expect(lastCall?.url == fileURL)
            #expect(lastCall?.config.table == chat.generateTableName())
        }

        // Test file progress updates
        let descriptor = FetchDescriptor<FileAttachment>()
        let files = try database.modelContainer.mainContext.fetch(descriptor)

        for file in files {
            try await database.write(FileCommands.UpdateProgress(
                fileId: file.id,
                fractionCompleted: 0.5
            ))

            let updatedFile = try await database.read(FileCommands.Get(fileId: file.id))
            #expect(updatedFile.progress == 0.5)
            #expect(updatedFile.ragState == .saving)
        }

        // Test concurrent access to files
        await withThrowingTaskGroup(of: Void.self) { group in
            for file in files {
                let id = file.id
                group.addTask {
                    try await database.writeInBackground(FileCommands.UpdateProgress(
                        fileId: id,
                        fractionCompleted: 1.0
                    ))
                }
            }
        }

        // Verify all files completed
        for file in files {
            let completedFile = try await database.read(FileCommands.Get(fileId: file.id))
            #expect(completedFile.progress == 1.0)
            #expect(completedFile.ragState == .saved)
        }

        // Test file deletion and RAG cleanup
        await mockRag.reset()

        for file in files {
            try await database.write(FileCommands.Delete(fileId: file.id))

            try await Task.sleep(nanoseconds: 1_000_000_000)
            let deleteOperations = await mockRag.deleteIDCalls
            #expect(!deleteOperations.isEmpty)
            #expect(deleteOperations.contains { $0.id == file.id })
        }

        // Verify final state
        let hasAttachments = try await database.read(ChatCommands.HasAttachments(chatId: chat.id))
        #expect(hasAttachments == false)

        // Cleanup
        for fileURL in fileURLs {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    @Test("RAG integration edge cases")
    @MainActor
    func ragIntegrationEdgeCases() async throws {
        // Given
        let mockRag = MockRagging()
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: mockRag)
        )

        let database = try Database.new(configuration: config)
        try await addRequiredModelsForFileTests(database)

        let defaultPersonalityId = try await getDefaultPersonalityId(database)
        try await database.write(ChatCommands.Create(personality: defaultPersonalityId))
        let chat = try await database.read(ChatCommands.GetFirst())

        // Test empty file
        let emptyFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("empty.txt")
        try "".write(to: emptyFileURL, atomically: true, encoding: .utf8)

        try await database.write(FileCommands.Create(
            fileURL: emptyFileURL,
            chatId: chat.id,
            database: database
        ))

        // Test large file
        let largeFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("large.txt")
        let largeContent = String(repeating: "Large content\n", count: 10000)
        try largeContent.write(to: largeFileURL, atomically: true, encoding: .utf8)

        try await database.write(FileCommands.Create(
            fileURL: largeFileURL,
            chatId: chat.id,
            database: database
        ))

        // Test Unicode content
        let unicodeFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("unicode.txt")
        let unicodeContent = "🌟 Unicode test 测试 テスト"
        try unicodeContent.write(to: unicodeFileURL, atomically: true, encoding: .utf8)

        try await database.write(FileCommands.Create(
            fileURL: unicodeFileURL,
            chatId: chat.id,
            database: database
        ))

        // Test concurrent file operations
        let fileCount = 5
        var concurrentFiles: [URL] = []

        for index in 0..<fileCount {
            let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("concurrent\(index).txt")
            try "Concurrent content \(index)".write(to: fileURL, atomically: true, encoding: .utf8)
            concurrentFiles.append(fileURL)
        }

        await withThrowingTaskGroup(of: Void.self) { group in
            for fileURL in concurrentFiles {
                let id = chat.id
                group.addTask {
                    try await database.writeInBackground(FileCommands.Create(
                        fileURL: fileURL,
                        chatId: id,
                        database: database
                    ))
                }
            }
        }

        // Verify all files processed
        try await Task.sleep(nanoseconds: 2_000_000_000)
        let ragCalls = await mockRag.addFileCalls
        #expect(ragCalls.count >= fileCount + 3) // Including previous files

        // Cleanup
        try? FileManager.default.removeItem(at: emptyFileURL)
        try? FileManager.default.removeItem(at: largeFileURL)
        try? FileManager.default.removeItem(at: unicodeFileURL)
        for fileURL in concurrentFiles {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
}
