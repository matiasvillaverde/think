import NaturalLanguage
import Foundation

/// Configuration for RAG operations
@DebugDescription
public struct Configuration: Sendable {
    public let tokenUnit: NLTokenUnit
    public let strategy: FileProcessingStrategy
    public let table: String
    public let chunking: ChunkingConfiguration

    public init(
        tokenUnit: NLTokenUnit = .paragraph,
        strategy: FileProcessingStrategy = .extractKeywords,
        table: String = Constants.defaultTable,
        chunking: ChunkingConfiguration = .disabled
    ) {
        self.tokenUnit = tokenUnit
        self.strategy = strategy
        self.table = table
        self.chunking = chunking
    }

    public static let `default` = Configuration()

    public var debugDescription: String {
        "Configuration(tokenUnit: \(tokenUnit), strategy: \(strategy), table: \(table), chunking: \(chunking))"
    }
}
