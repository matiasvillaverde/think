import Foundation

internal struct EmbeddingFixture: Codable, Equatable {
    let model: String
    let text: String
    let dimension: Int
    let embedding: [Float]
}

internal enum EmbeddingFixturePaths {
    static let directoryName: String = "Fixtures"
    static let fileName: String = "embedding_fixture"
    static let fileExtension: String = "json"

    static func resourceURL() throws -> URL {
        guard let url = Bundle.module.url(
            forResource: fileName,
            withExtension: fileExtension,
            subdirectory: directoryName
        ) else {
            throw FixtureError.missingResource
        }
        return url
    }

    static func fileURLForGeneration(currentFile: String = #filePath) -> URL {
        URL(fileURLWithPath: currentFile)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(directoryName)
            .appendingPathComponent("\(fileName).\(fileExtension)")
    }

    enum FixtureError: Error {
        case missingResource
    }
}
