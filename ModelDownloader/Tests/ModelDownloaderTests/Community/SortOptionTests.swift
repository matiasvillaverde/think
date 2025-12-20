import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

@Suite("SortOption Tests")
struct SortOptionTests {
    @Test("SortOption API parameters")
    func testAPIParameters() {
        #expect(SortOption.downloads.apiParameter == "downloads")
        #expect(SortOption.likes.apiParameter == "likes")
        #expect(SortOption.lastModified.apiParameter == "lastModified")
        #expect(SortOption.trending.apiParameter == "trending")
    }

    @Test("SortOption display names")
    func testDisplayNames() {
        #expect(SortOption.downloads.displayName == "Most Downloaded")
        #expect(SortOption.likes.displayName == "Most Liked")
        #expect(SortOption.lastModified.displayName == "Recently Updated")
        #expect(SortOption.trending.displayName == "Trending")
    }

    @Test("SortOption is CaseIterable")
    func testCaseIterable() {
        let allCases: [SortOption] = SortOption.allCases
        #expect(allCases.count == 4)
        #expect(allCases.contains(.downloads))
        #expect(allCases.contains(.likes))
        #expect(allCases.contains(.lastModified))
        #expect(allCases.contains(.trending))
    }

    @Test("SortOption is Codable")
    func testCodable() throws {
        let original: SortOption = SortOption.downloads

        let encoder: JSONEncoder = JSONEncoder()
        let data: Data = try encoder.encode(original)

        let decoder: JSONDecoder = JSONDecoder()
        let decoded: SortOption = try decoder.decode(SortOption.self, from: data)

        #expect(decoded == original)
    }
}
