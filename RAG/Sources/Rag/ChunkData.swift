import Foundation
import NaturalLanguage

// MARK: - Public Types
internal struct ChunkData: Sendable {
    let text: String
    let keywords: String
    let pageIndex: Int
    let localChunkIndex: Int
}
