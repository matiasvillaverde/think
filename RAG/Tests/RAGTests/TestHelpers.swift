import Abstractions
import Foundation
@testable import Rag

internal enum TestHelpers {
    /// Returns the URL to the local test model
    static var localModelURL: URL {
        let bundle: Bundle = Bundle.module
        return bundle.url(forResource: "all-MiniLM-L6-v2", withExtension: nil)
        ?? URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .appendingPathComponent("all-MiniLM-L6-v2")
    }

    static var isLocalModelAvailable: Bool {
        let modelURL: URL = localModelURL.appendingPathComponent("model.safetensors")
        return FileManager.default.fileExists(atPath: modelURL.path)
    }

    /// Creates a Rag instance with the local test model
    static func createTestRag(
        from hubRepoId: String = "sentence-transformers/all-MiniLM-L6-v2",
        database: DatabaseLocation = .inMemory,
        loadingStrategy: RagLoadingStrategy = .lazy
    ) async throws -> Rag {
        // For invalid repo IDs (used in error testing), don't provide local URL
        let shouldUseLocal: Bool = hubRepoId == "sentence-transformers/all-MiniLM-L6-v2"

        return try await Rag(
            from: hubRepoId,
            local: shouldUseLocal ? localModelURL : nil,
            useBackgroundSession: false,
            database: database,
            loadingStrategy: loadingStrategy
        )
    }

    static func createTestRagIfAvailable(
        from hubRepoId: String = "sentence-transformers/all-MiniLM-L6-v2",
        database: DatabaseLocation = .inMemory,
        loadingStrategy: RagLoadingStrategy = .lazy
    ) async throws -> Rag? {
        guard isLocalModelAvailable else {
            return nil
        }

        return try await createTestRag(
            from: hubRepoId,
            database: database,
            loadingStrategy: loadingStrategy
        )
    }

    static func createTempFile(content: String, fileExtension: String) throws -> URL {
        let tempDir: URL = FileManager.default.temporaryDirectory
        let fileURL: URL = tempDir
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
}
